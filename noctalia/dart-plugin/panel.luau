--!nonstrict
--[[
Run-list panel (entry "panel" of dani/dart).

Layout: header (title, counts, refresh, close) -> filter bar -> scrollable
run cards. Each card collapses to [state dot | id | open | copy | link |
commit | project | uptime | created (local tz) | priority | state pill |
chevron] plus one row of tag chips; expanding it adds the full wrapped tag
rows, an info line (clusters / updated), the
description, a tag editor, and state-gated action buttons. Right-clicking any
header button opens the same actions as a native context menu, so the common
ones are reachable without expanding the card.

Data flow: this panel never talks to `dart run filter` itself — service.luau
polls and publishes "runs"/"error"/"busy" via noctalia.state, and the panel
asks for refreshes over the "command" state channel. Mutations (cancel /
suspend / resume / delete, tag add / delete / replace) DO run here via
noctalia.runAsync, then request a list refresh.

Conventions:
- All colors are palette-role tokens so the wallpaper-derived theme applies.
- Handler props (onClick/onSubmit/onChange) take closures directly: the
  reconciler moves any function-valued prop into its own handler table and
  names it after the node's path, so per-row handlers need no global names.
  Cards carry key = "run-<id>", which is what makes those paths stable.
  panel.openContextMenu is the exception - its onActivate is still dispatched
  by global name, hence onRunMenu() at the bottom of this file.
- Every spawn is an argv table (noctalia.runAsync{...}), so no value is ever
  shell-quoted by hand. The two inputs that really are word lists - $BROWSER,
  which may carry its own arguments, and the filter bar's free-form
  `dart run filter` args - are split by common.splitWords, not by a shell.
- Helpers the entries share (run URL, run-id guard, refresh request, word
  splitting) live in common.luau, loaded with require().
]]

-- ═══════════════════════════════════════════════════ config & constants ═══

local common = require("./common.luau")
local requestRefresh = common.requestRefresh
local validRunId = common.validRunId

local DART = noctalia.getConfig("dart_path")

-- `dart logs` shells out to logcli; until `nh os switch` puts grafana-loki on
-- the PATH (home.packages in noctalia/default.nix), fall back to the store
-- path the sai FHS env already built.
local LOGCLI_DIR = "/nix/store/hy901jc1mgirc5g8lasy91zbkk013dzk-grafana-loki-3.7.2/bin"

-- Layout constants, all derived from the manifest's panel width (1200):
local FILTER_INPUT_WIDTH = 1040 -- inputs ignore flexGrow; width is the knob
local TAG_INPUT_WIDTH = 420
local CHIP_ROW_BUDGET = 1100 -- panel minus panel/card padding, conservative
local CHIP_MAX_CHARS = 44 -- longer tags are ellipsized on the chip
local CHIP_PX_PER_CHAR = 5.3 -- fontSize-11 width estimate for row packing

-- Theme-role color per run state; anything unlisted (the startup states:
-- submitting/building/queued/...) falls through to "secondary".
local STATE_COLOR = {
	running = "primary",
	suspended = "tertiary",
	suspended_manual = "tertiary",
	suspending = "tertiary",
	suspending_manual = "tertiary",
	suspend_requested_manual = "tertiary",
	erroring = "error",
	error = "error",
	build_error = "error",
	cancel_requested = "on_surface_variant",
	canceling = "on_surface_variant",
	canceled = "on_surface_variant",
}

-- States `dart run cancel` accepts, per dart_client/api.py. Suspend is only
-- legal from "running" and resume only from "suspended_manual" (checked
-- inline where the buttons are built).
local CANCELABLE = {
	building = true,
	queued = true,
	resume_requested_manual = true,
	running = true,
	preparing = true,
	scheduling = true,
	submitted = true,
	suspended = true,
	suspended_manual = true,
	suspending = true,
	suspending_manual = true,
	suspend_requested_manual = true,
}

-- ═══════════════════════════════════════════════════════════ view state ═══

-- Mirrors of the service's published state (kept fresh by the watchers at
-- the bottom of this file).
local runs = noctalia.state.get("runs") or {}
local err = noctalia.state.get("error")
local busy = noctalia.state.get("busy") or false

-- Panel-local interaction state. The panel VM persists across open/close,
-- so onClose() resets whatever should not greet the next open.
local isOpen = true -- guards render(); true by default so a hot reload while open keeps drawing
local expandedId = nil -- run id whose detail section is open
local pending = nil -- { id, action } awaiting the destructive-confirm click
local actionBusy = nil -- run id with a run mutation in flight (disables buttons)
local editTagsId = nil -- run id in tag-edit mode
local editingOldTag = nil -- tag loaded into the tag input; Enter replaces it
local tagGen = 0 -- bumped to re-key (clear) the tag input
local customFilter = noctalia.state.get("custom_filter") -- verbatim filter args; nil = defaults
local filterDraft = customFilter or "" -- filter input text, tracked via onChange
local filterGen = 0 -- bumped to re-key (reseed) the filter input

local render -- fwd decl; defined in the render section

-- ═══════════════════════════════════════════════ run metadata helpers ═══

local function stateColor(state)
	return STATE_COLOR[state] or "secondary"
end

-- Description: first-class config.description on modern runs, description=
-- tag as the legacy fallback. Horizon runs embed <b>/<big> markup - strip it.
local function describe(run)
	local d = run.description
	if type(d) == "string" and d ~= "" then
		return (d:gsub("<[^>]->", ""))
	end
	for _, t in ipairs(run.tags or {}) do
		local m = t:match("^description=(.*)$")
		if m then
			return m
		end
	end
	return "(no description)"
end

-- The context menu carries only a run id (see openRunMenu), so items that need
-- more of the run than its id look it up in the current list.
local function runById(id)
	for _, r in ipairs(runs) do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- Tags worth showing as chips (the description= tag is prose, not a tag).
local function chipTags(run)
	local out = {}
	for _, t in ipairs(run.tags or {}) do
		if not t:match("^description=") then
			out[#out + 1] = t
		end
	end
	return out
end

-- Days-since-epoch for a UTC civil date (Howard Hinnant's algorithm). Only
-- ever called with a real calendar date pulled out of an ISO timestamp, so
-- no need to handle y < 0.
local function daysFromCivil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = y // 400
	local yoe = y - era * 400
	local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- ISO UTC timestamp -> Unix epoch seconds. Doesn't use os.time({...}), which
-- treats the table as *local* time and would skew by the machine's UTC
-- offset.
local function epochFromIso(iso)
	if type(iso) ~= "string" then
		return nil
	end
	local y, mo, d, h, mi, s = iso:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	local days = daysFromCivil(tonumber(y), tonumber(mo), tonumber(d))
	return days * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(s)
end

-- ISO UTC timestamp -> "07-15 16:32", through noctalia's own formatter (the
-- one the clock settings use). localShortTime renders in the machine's
-- timezone; shortTime passes "UTC" (plugin API 19) to match what the DART web
-- UI shows.
local SHORT_TIME = "{:%m-%d %H:%M}"

local function localShortTime(iso)
	local epoch = epochFromIso(iso)
	return if epoch then noctalia.formatTime(SHORT_TIME, epoch) else ""
end

local function shortTime(iso)
	local epoch = epochFromIso(iso)
	return if epoch then noctalia.formatTime(SHORT_TIME, epoch, "UTC") else ""
end

-- Wall-clock time a run has been alive: created_at -> now, as "<d>d<h>h<m>m".
local function uptime(iso)
	local created = epochFromIso(iso)
	if not created then
		return ""
	end
	local elapsed = os.time() - created
	if elapsed < 0 then
		elapsed = 0
	end
	local days = elapsed // 86400
	local hours = (elapsed % 86400) // 3600
	local minutes = (elapsed % 3600) // 60
	return days .. "d" .. hours .. "h" .. minutes .. "m"
end

-- ═══════════════════ actions: everything that leaves the panel process ═══

-- Publish verbatim `dart run filter` args (service.luau adds them after the
-- default --username-ss/--limit). Empty text returns to the default query.
-- The text never reaches a shell - service.luau splits it into an argv spawn
-- with common.splitWords - so the one thing to refuse here is text that does
-- not split, i.e. an unterminated quote. Quotes, spaces, =, commas and even
-- $() are all just characters in a filter value.
local function applyFilter(text)
	text = noctalia.string.trim(text or "")
	local words, splitErr = common.splitWords(text)
	if not words then
		noctalia.notifyError("dart filter", splitErr)
		return
	end
	customFilter = text ~= "" and text or nil
	filterDraft = text
	noctalia.state.set("custom_filter", customFilter)
	requestRefresh()
	render()
end

-- Tag chip click: search for that tag. common.quoteWord keeps the filter text
-- readable and editable, and splitWords undoes it exactly, so any tag is
-- searchable, one containing a quote included.
local function filterByTag(tag)
	filterGen += 1 -- re-key the input so it shows the new filter text
	applyFilter("--tag-ss " .. common.quoteWord(tag))
end

-- Same URL dart.nvim opens, or nil when the id would not survive being a path
-- segment. One guard for both consumers: the open button spawns it, the link
-- button copies it, and neither can produce a URL the other would refuse.
local function runUrl(id)
	if not validRunId(id) then
		return nil
	end
	return common.DETAILS_URL .. id
end

-- Detached spawn (runAsync without a callback) so the browser outlives the
-- shell.
local function openInBrowser(id)
	local url = runUrl(id)
	if not url then
		return
	end
	noctalia.runAsync(common.browserArgv(url))
end

-- dart.nvim's <leader>l equivalent. `dart logs` downloads per-pod files into
-- <cwd>/<run-id>/, so run it under /tmp/dart-logs and browse the result with
-- yazi, all inside one held kitty window (errors stay visible).
local function openLogs(id)
	if not validRunId(id) then
		return
	end
	-- The outer spawn is an argv table, so nothing here passes through a shell
	-- to be quoted. The inner `sh -c` still needs a shell (&&, cd), but it takes
	-- the dart path and run id as $1/$2 instead of interpolating them - which is
	-- what forced the doubly-escaped \\$PATH in the old single-string form.
	local script = "mkdir -p /tmp/dart-logs && cd /tmp/dart-logs && PATH=$PATH:"
		.. LOGCLI_DIR
		.. ' && "$1" logs -r "$2" -l 2000 && yazi "$2"'
	noctalia.runAsync({ "kitty", "--hold", "-e", "sh", "-c", script, "sh", DART, id })
end

-- Tag mutations:
--   add/delete: dart tag <action> --run-ids <id> --tag <tag>
--   replace:    dart tag replace --run-ids <id> --old-tag <old> --new-tag <new>
-- One tag per call (the CLI has no batch form), toast the outcome, re-poll.
local function tagAction(action, id, tag, oldTag)
	tag = noctalia.string.trim(tag or "")
	if tag == "" then
		return
	end
	-- No quote/newline guard: argv hands each value to execve as its own
	-- element, so a tag containing ' or " or a newline is passed through
	-- verbatim.
	local argv
	if action == "replace" then
		argv = { DART, "tag", "replace", "--run-ids", id, "--old-tag", oldTag, "--new-tag", tag }
	else
		argv = { DART, "tag", action, "--run-ids", id, "--tag", tag }
	end
	noctalia.runAsync(argv, function(res)
		if res.timedOut or res.exitCode ~= 0 then
			noctalia.notifyError("dart tag " .. action .. " failed", res.stderr:sub(-300))
		else
			noctalia.notify(
				"dart tag " .. action,
				action == "replace" and (oldTag .. " -> " .. tag) or (id .. ": " .. tag)
			)
		end
		requestRefresh()
	end, 30000)
end

-- Run mutations (cancel / suspend / resume / delete). The CLI has no confirm
-- flag and prints a multi-line ModifiedRuns JSON object on success - parse
-- ALL of stdout (not the last line) and toast what actually happened.
local function runAction(action, id)
	if not validRunId(id) then
		return
	end
	actionBusy, pending = id, nil
	render()
	local ok = noctalia.runAsync({ DART, "run", action, id }, function(res)
		actionBusy = nil
		if res.timedOut or res.exitCode ~= 0 then
			noctalia.notifyError(
				"dart " .. action .. " failed",
				res.timedOut and "timed out - try `dart login` in a terminal" or res.stderr:sub(-300)
			)
		else
			local mod = noctalia.json.decode(res.stdout)
			if type(mod) == "table" and mod.successful_ids and #mod.successful_ids > 0 then
				noctalia.notify("dart " .. action, table.concat(mod.successful_ids, ", "))
			elseif type(mod) == "table" and mod.noop_ids and #mod.noop_ids > 0 then
				noctalia.notify("dart " .. action, id .. ": no-op")
			else
				noctalia.notifyError("dart " .. action, id .. " was not modified")
			end
		end
		requestRefresh()
		render()
	end, 30000)
	if not ok then -- async-command slots exhausted
		actionBusy = nil
		noctalia.notifyError("dart", "too many commands in flight - try again")
		render()
	end
end

local function copyToClipboard(label, text)
	if noctalia.copyToClipboard(text, "text/plain") then
		noctalia.notify(label, text)
	end
end

-- The URL behind the open button, on the clipboard instead of in a browser -
-- what you want when the run is going into a message or a ticket. Has to sit
-- below copyToClipboard: `local function` is only in scope after its own
-- declaration, so calling it from further up would silently resolve to a nil
-- global instead.
local function copyRunUrl(id)
	local url = runUrl(id)
	if not url then
		return
	end
	copyToClipboard("Copied URL", url)
end

-- ═══════════════════════════════════════════════════════ UI builders ═══

-- Scheduling priority pill, sat just left of the state pill. DART schedules the
-- highest priority first, and a run submitted without one counts as 0
-- (dart_client/hydra.py), so a missing value shows as 0 rather than nothing.
-- tostring drops the ".0" the API sends for whole numbers (-1.0 -> "-1").
local function priorityChip(run)
	local priority = tonumber(run.priority) or 0
	return ui.row(
		{ fill = "on_surface_variant/0.12", radius = 9, paddingH = 8, paddingV = 2, gap = 4, align = "center" },
		{
			ui.glyph({ name = "arrows-sort", size = 12, color = "on_surface_variant" }),
			ui.label({
				text = tostring(priority),
				color = "on_surface_variant",
				fontWeight = "semibold",
				fontSize = 11,
			}),
		}
	)
end

-- Non-interactive pill (used for the project chip).
local function chip(text, fillRole, textRole)
	return ui.row({ fill = fillRole, radius = 9, paddingH = 8, paddingV = 2, align = "center" }, {
		ui.label({ text = text, color = textRole, fontSize = 11, maxWidth = 200, maxLines = 1 }),
	})
end

-- One tag chip -> (node, estimatedWidth). Chips are compact buttons rather than
-- clickable rows: a row takes onClick, but only a button carries the tooltip
-- that says what the click does. Normal mode: click searches for the tag.
-- Edit mode: [tag -> load into the input for replace] [x -> delete].
local function tagChip(tag, editing, runId)
	local disp = #tag > CHIP_MAX_CHARS and (tag:sub(1, CHIP_MAX_CHARS - 3) .. "...") or tag
	local textWidth = math.min(#disp * CHIP_PX_PER_CHAR, 250)
	if editing then
		return ui.row({ gap = 2, align = "center" }, {
			ui.button({
				text = disp,
				fontSize = 11,
				height = 22,
				variant = "outline",
				selected = (editingOldTag == tag),
				tooltip = "Edit tag (loads it into the input; Enter replaces)",
				onClick = function()
					editingOldTag = tag
					render()
				end,
			}),
			ui.button({
				glyph = "x",
				glyphSize = 11,
				height = 22,
				variant = "ghost",
				tooltip = "Delete tag '" .. tag .. "'",
				onClick = function()
					tagAction("delete", runId, tag)
				end,
			}),
		}),
			textWidth + 72
	end
	return ui.button({
		text = disp,
		fontSize = 11,
		height = 22,
		variant = "secondary",
		tooltip = "Search: --tag-ss " .. common.quoteWord(tag),
		onClick = function()
			filterByTag(tag)
		end,
	}),
		textWidth + 26
end

-- Flex rows can't wrap (the C++ Flex has setWrap but the reconciler doesn't
-- expose it), so chips are packed into rows by estimated pixel width.
-- Collapsed cards keep only the first row plus a "+n" overflow label;
-- expanded cards show every row.
local function chipRowNodes(run, expanded)
	local tags = chipTags(run)
	if #tags == 0 then
		return {}
	end
	local editing = (editTagsId == run.id)
	local rows, cur, curW, placed = {}, {}, 0, 0
	for _, t in ipairs(tags) do
		local node, w = tagChip(t, editing, run.id)
		if curW + w > CHIP_ROW_BUDGET and #cur > 0 then
			if not expanded then
				break
			end
			rows[#rows + 1] = ui.row({ gap = 6, align = "center" }, cur)
			cur, curW = {}, 0
		end
		cur[#cur + 1] = node
		curW += w
		placed += 1
	end
	if not expanded and placed < #tags then
		cur[#cur + 1] = ui.label({ text = "+" .. (#tags - placed), color = "on_surface_variant", fontSize = 11 })
	end
	if #cur > 0 then
		rows[#rows + 1] = ui.row({ gap = 6, align = "center" }, cur)
	end
	return rows
end

-- Copyable commit chip; nil when the run carries no commit. The chip shows the
-- usual 12-char prefix, the clipboard gets the full hash.
local function commitButton(run)
	if not run.git_commit or run.git_commit == "" then
		return nil
	end
	return ui.button({
		glyph = "git-commit",
		glyphSize = 13,
		text = run.git_commit:sub(1, 12),
		fontSize = 11,
		height = 22,
		variant = "ghost",
		tooltip = "Copy full commit hash",
		onClick = function()
			copyToClipboard("Copied commit", run.git_commit)
		end,
	})
end

-- Per-run context menu, opened by right-clicking any of the card's header
-- buttons. Three constraints from the host shape this:
--   * openContextMenu needs a live pointer serial, and only onRightClick
--     carries one - an onClick handler would silently get `false` back. So
--     there is no left-click "..." button; right-click is the whole gesture.
--   * onActivate is dispatched by GLOBAL name (unlike the render tree's
--     handler props, which take closures), so the run id travels in `context`
--     rather than being captured - see onRunMenu() at the bottom.
--   * Items are label + enabled only; the menu has no icons or shortcuts.
-- `enabled` must be a real boolean, hence the `== true` on the CANCELABLE
-- lookup, which is otherwise nil for a state that cannot be cancelled.
local function openRunMenu(run)
	local free = (actionBusy == nil)
	local items = {
		{ kind = "header", label = run.id },
		{ kind = "item", id = "open", label = "Open in browser" },
		{ kind = "item", id = "copy", label = "Copy run id" },
		{ kind = "item", id = "copyurl", label = "Copy run URL" },
	}
	if run.git_commit and run.git_commit ~= "" then
		items[#items + 1] = { kind = "item", id = "copycommit", label = "Copy commit hash" }
	end
	items[#items + 1] = { kind = "item", id = "logs", label = "Logs (download, browse in yazi)" }
	items[#items + 1] = { kind = "item", id = "tags", label = "Edit tags" }
	items[#items + 1] = { kind = "separator" }
	items[#items + 1] = { kind = "item", id = "suspend", label = "Suspend", enabled = free and run.state == "running" }
	items[#items + 1] =
		{ kind = "item", id = "resume", label = "Resume", enabled = free and run.state == "suspended_manual" }
	items[#items + 1] =
		{ kind = "item", id = "cancel", label = "Cancel run", enabled = free and CANCELABLE[run.state] == true }
	items[#items + 1] = { kind = "separator" }
	items[#items + 1] = { kind = "item", id = "delete", label = "Delete run", enabled = free }
	panel.openContextMenu({ onActivate = "onRunMenu", context = run.id, items = items })
end

-- Card header: state dot | run id | open | copy | link | ... | commit |
-- project | uptime | created (local tz) | priority | state pill | chevron.
--
-- The id is a bold label with separate open/copy/link buttons beside it, not a
-- clickable row wrapped around the label. Rows do take onClick, but only
-- ui.button carries a tooltip and the onRightClick that openRunMenu needs, and
-- every header control answers right-click with the run menu.
local function cardHeader(run, expanded, color)
	-- Shared by every header button: right-click anywhere in the control
	-- cluster opens the run menu, so the gesture does not depend on hitting
	-- one specific glyph.
	local menu = function()
		openRunMenu(run)
	end
	local bits = {
		ui.glyph({ name = "point-filled", size = 16, color = color }),
		ui.label({ text = run.id, color = "on_surface", fontWeight = "bold", fontSize = 13, maxLines = 1 }),
		ui.button({
			glyph = "external-link",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Open in browser (right-click: menu)",
			onClick = function()
				openInBrowser(run.id)
			end,
			onRightClick = menu,
		}),
		ui.button({
			glyph = "copy",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Copy run id (right-click: menu)",
			onClick = function()
				copyToClipboard("Copied", run.id)
			end,
			onRightClick = menu,
		}),
		-- Same target as the open button beside it, to the clipboard rather
		-- than to $BROWSER. "link" not "copy": the pair reads as id-vs-URL at a
		-- glance, which two copy glyphs would not.
		ui.button({
			glyph = "link",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Copy run URL (right-click: menu)",
			onClick = function()
				copyRunUrl(run.id)
			end,
			onRightClick = menu,
		}),
		ui.spacer({ flexGrow = 1 }),
	}
	local commit = commitButton(run)
	if commit then
		bits[#bits + 1] = commit
	end
	if run.project and run.project ~= "" then
		bits[#bits + 1] = chip(run.project, "tertiary/0.18", "tertiary")
	end
	local running = uptime(run.created_at)
	if running ~= "" then
		bits[#bits + 1] = ui.glyph({ name = "clock", size = 12, color = "on_surface_variant" })
		bits[#bits + 1] = ui.label({ text = running, color = "on_surface_variant", fontSize = 11 })
	end
	local created = localShortTime(run.created_at)
	if created ~= "" then
		bits[#bits + 1] = ui.glyph({ name = "calendar", size = 12, color = "on_surface_variant" })
		bits[#bits + 1] = ui.label({ text = created, color = "on_surface_variant", fontSize = 11 })
	end
	bits[#bits + 1] = priorityChip(run)
	bits[#bits + 1] = ui.row({ fill = color .. "/0.15", radius = 9, paddingH = 8, paddingV = 2, align = "center" }, {
		ui.label({ text = run.state, color = color, fontWeight = "semibold", fontSize = 11 }),
	})
	bits[#bits + 1] = ui.button({
		glyph = expanded and "chevron-up" or "chevron-down",
		variant = "ghost",
		controlSize = "sm",
		tooltip = (expanded and "Collapse" or "Description & actions") .. " (right-click: menu)",
		onClick = function()
			-- NB: `expanded and nil or run.id` would ALWAYS yield run.id (Lua
			-- ternary pitfall with nil), hence the explicit branch.
			if expandedId == run.id then
				expandedId = nil
			else
				expandedId = run.id
			end
			pending = nil
			editTagsId = nil
			editingOldTag = nil
			render()
		end,
		onRightClick = menu,
	})
	return ui.row({ gap = 8, align = "center" }, bits)
end

-- Info line of an expanded card: clusters | last update. (The commit lives in
-- the header now, on every card.) All fields come from the slimmed filter
-- payload - no extra CLI calls.
local function infoLine(run)
	local info = {}
	local clusters = {}
	for name, st in pairs(run.clusters or {}) do
		clusters[#clusters + 1] = st and (name .. " (" .. st .. ")") or name
	end
	table.sort(clusters)
	if #clusters > 0 then
		info[#info + 1] = ui.glyph({ name = "server", size = 13, color = "on_surface_variant" })
		info[#info + 1] = ui.label({
			text = table.concat(clusters, ", "),
			color = "on_surface_variant",
			fontSize = 11,
			maxLines = 1,
			maxWidth = 500,
		})
	end
	local updated = shortTime(run.state_updated_at)
	if updated ~= "" then
		info[#info + 1] = ui.glyph({ name = "clock-edit", size = 13, color = "on_surface_variant" })
		info[#info + 1] = ui.label({ text = "updated " .. updated, color = "on_surface_variant", fontSize = 11 })
	end
	if #info == 0 then
		return nil
	end
	return ui.row({ gap = 6, align = "center", paddingH = 4 }, info)
end

-- Tag editor row (only in edit mode): an input that adds a new tag, or -
-- when a chip loaded a tag - replaces it on Enter, plus a cancel button.
local function tagEditorRow(run)
	local nodes = {
		ui.input({
			-- key carries tagGen + the loaded tag: bumping tagGen clears the
			-- (uncontrolled) input, loading a tag reseeds it with that value.
			key = "tagadd-" .. run.id .. "-" .. tagGen .. "-" .. (editingOldTag or ""),
			value = editingOldTag or "",
			placeholder = "add tag (Enter), e.g. expt=my_experiment",
			fontSize = 12,
			controlSize = "sm",
			width = TAG_INPUT_WIDTH,
			onSubmit = function(text)
				tagGen += 1
				if editingOldTag then
					local old = editingOldTag
					editingOldTag = nil
					tagAction("replace", run.id, text, old)
				else
					tagAction("add", run.id, text)
				end
			end,
		}),
	}
	if editingOldTag then
		nodes[#nodes + 1] = ui.button({
			glyph = "x",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Cancel edit (back to adding)",
			onClick = function()
				editingOldTag = nil
				tagGen += 1
				render()
			end,
		})
		nodes[#nodes + 1] = ui.label({
			text = "editing '" .. editingOldTag .. "' - Enter replaces it",
			color = "primary",
			fontSize = 11,
			maxLines = 1,
			maxWidth = 460,
		})
	else
		nodes[#nodes + 1] = ui.label({
			text = "click a tag to edit it, x to delete",
			color = "on_surface_variant",
			fontSize = 11,
		})
	end
	return ui.row({ gap = 6, align = "center" }, nodes)
end

-- Action buttons of an expanded card. A pending cancel/delete swaps the whole
-- row for an inline confirm (the CLI is non-interactive, so the widget owns
-- the confirmation step). Suspend/resume act immediately - they're cheap to
-- undo. Gating mirrors dart_client's state machine.
local function actionButtons(run)
	if pending and pending.id == run.id then
		return {
			ui.label({
				text = "Really " .. pending.action .. " " .. run.id .. "?",
				color = "error",
				fontWeight = "medium",
				fontSize = 12,
			}),
			ui.button({
				text = "Yes",
				glyph = "check",
				variant = "destructive",
				controlSize = "sm",
				onClick = function()
					runAction(pending.action, run.id)
				end,
			}),
			ui.button({
				text = "No",
				glyph = "x",
				variant = "ghost",
				controlSize = "sm",
				onClick = function()
					pending = nil
					render()
				end,
			}),
		}
	end
	local btns, enabled = {}, (actionBusy == nil)
	btns[#btns + 1] = ui.button({
		text = "Logs",
		glyph = "file-text",
		variant = "ghost",
		controlSize = "sm",
		tooltip = "Download pod logs, browse with yazi",
		onClick = function()
			openLogs(run.id)
		end,
	})
	btns[#btns + 1] = ui.button({
		text = "Tags",
		glyph = (editTagsId == run.id) and "pencil-off" or "pencil",
		variant = "ghost",
		controlSize = "sm",
		tooltip = (editTagsId == run.id) and "Done editing tags" or "Edit tags (add/edit/delete)",
		onClick = function()
			-- if-then-else, not `and nil or`: the latter always yields run.id,
			-- since `cond and nil` is nil and `nil or run.id` then falls through.
			editTagsId = if editTagsId == run.id then nil else run.id
			editingOldTag = nil
			render()
		end,
	})
	if CANCELABLE[run.state] then
		btns[#btns + 1] = ui.button({
			text = "Cancel",
			glyph = "player-stop",
			variant = "outline",
			controlSize = "sm",
			enabled = enabled,
			onClick = function()
				pending = { id = run.id, action = "cancel" }
				render()
			end,
		})
	end
	if run.state == "running" then
		btns[#btns + 1] = ui.button({
			text = "Suspend",
			glyph = "player-pause",
			variant = "outline",
			controlSize = "sm",
			enabled = enabled,
			onClick = function()
				runAction("suspend", run.id)
			end,
		})
	end
	if run.state == "suspended_manual" then
		btns[#btns + 1] = ui.button({
			text = "Resume",
			glyph = "player-play",
			variant = "primary",
			controlSize = "sm",
			enabled = enabled,
			onClick = function()
				runAction("resume", run.id)
			end,
		})
	end
	btns[#btns + 1] = ui.button({
		text = "Delete",
		glyph = "trash",
		variant = "destructive",
		controlSize = "sm",
		enabled = enabled,
		onClick = function()
			pending = { id = run.id, action = "delete" }
			render()
		end,
	})
	if actionBusy == run.id then
		btns[#btns + 1] = ui.label({ text = "working...", color = "on_surface_variant", fontSize = 12 })
	end
	return btns
end

-- One run card. Cards carry their own fill so runs read as clearly delimited
-- blocks; the expanded card gets a stronger fill plus an outline border.
local function runCard(run)
	local expanded = (expandedId == run.id)
	local color = stateColor(run.state)

	local children = { cardHeader(run, expanded, color) }
	for _, rowNode in ipairs(chipRowNodes(run, expanded)) do
		children[#children + 1] = rowNode
	end

	if expanded then
		children[#children + 1] = ui.separator({ spacing = 4, color = "outline/0.4" })
		children[#children + 1] = infoLine(run)
		children[#children + 1] = ui.label({
			text = describe(run),
			color = "on_surface",
			fontSize = 13,
			maxLines = 8,
		})
		if run.state_info ~= "" then
			children[#children + 1] = ui.label({
				text = run.state_info,
				color = "tertiary",
				fontSize = 11,
				maxLines = 3,
			})
		end
		if editTagsId == run.id then
			children[#children + 1] = tagEditorRow(run)
		end
		children[#children + 1] = ui.row({ gap = 8, align = "center", justify = "end" }, actionButtons(run))
	end

	-- infoLine may return nil; compact the children array so the reconciler
	-- never sees holes.
	local compact = {}
	for _, c in ipairs(children) do
		if c ~= nil then
			compact[#compact + 1] = c
		end
	end

	local props = {
		key = "run-" .. run.id,
		gap = 6,
		padding = 10,
		radius = 14,
		fill = expanded and "surface_variant/0.75" or "surface_variant/0.35",
	}
	if expanded then
		props.border = "outline/0.5"
		props.borderWidth = 1
	end
	return ui.column(props, compact)
end

local function centered(nodes)
	return ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 10 }, nodes)
end

-- Filter bar: free-form `dart run filter` args (service.luau keeps them
-- scoped to --limit/--username-ss unless overridden). Enter or the search
-- button applies; filter-off returns to the default query.
local function filterBar()
	return ui.row({ gap = 8, align = "center" }, {
		ui.input({
			key = "filter-" .. filterGen,
			value = customFilter or "",
			placeholder = "dart run filter args, e.g. --tag-ss expt=foo --states success --username-ss bob",
			fontSize = 12,
			controlSize = "sm",
			width = FILTER_INPUT_WIDTH,
			onChange = "onFilterChange",
			onSubmit = "onFilterSubmit",
		}),
		ui.button({
			glyph = "search",
			variant = customFilter and "primary" or "ghost",
			controlSize = "sm",
			tooltip = "Apply filter",
			onClick = "onFilterApply",
		}),
		customFilter and ui.button({
			glyph = "filter-off",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Clear filter (back to defaults)",
			onClick = "onFilterClear",
		}) or ui.spacer({ width = 1 }),
	})
end

local function headerBar()
	local running = 0
	for _, r in ipairs(runs) do
		if r.state == "running" then
			running += 1
		end
	end
	local subtitle = #runs > 0 and (#runs .. " active · " .. running .. " running") or ""
	return ui.row({ align = "center", gap = 10 }, {
		ui.glyph({ name = "target-arrow", size = 20, color = "primary" }),
		ui.label({ text = "DART runs", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
		ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 12, flexGrow = 1 }),
		busy and ui.label({ text = "refreshing...", color = "on_surface_variant", fontSize = 12 })
			or ui.spacer({ width = 1 }),
		ui.button({
			glyph = "refresh",
			variant = "ghost",
			enabled = not busy,
			tooltip = "Refresh now",
			onClick = "onRefreshClicked",
		}),
		ui.button({ glyph = "x", variant = "ghost", tooltip = "Close", onClick = "onCloseClicked" }),
	})
end

-- ═══════════════════════════════════════════════════════════════ render ═══

render = function()
	if not isOpen then
		return -- state.watch keeps firing while closed; skip the wasted work
	end

	local body
	if err then
		body = centered({
			ui.glyph({ name = "alert-triangle", size = 40, color = "error" }),
			ui.label({ text = "dart CLI error", color = "error", fontWeight = "bold", fontSize = 15 }),
			ui.label({
				text = err,
				color = "on_surface_variant",
				fontSize = 12,
				maxLines = 8,
				textAlign = "center",
				maxWidth = 700,
			}),
		})
	elseif #runs == 0 then
		body = centered({
			ui.glyph({ name = "target-arrow", size = 40, color = "on_surface_variant/0.6" }),
			ui.label({
				text = busy and "Loading runs..." or (customFilter and "No runs match the filter" or "No active runs"),
				color = "on_surface_variant",
				fontSize = 14,
			}),
		})
	else
		local cards = {}
		for _, run in ipairs(runs) do
			cards[#cards + 1] = runCard(run)
		end
		body = ui.scroll({ flexGrow = 1, gap = 8 }, cards)
	end

	panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
		headerBar(),
		filterBar(),
		body,
	}))
end

-- ═══════════════════════════ state subscriptions & host entry points ═══

noctalia.state.watch("runs", function(v)
	runs = v or {}
	render()
end)
noctalia.state.watch("error", function(v)
	err = v
	render()
end)
noctalia.state.watch("busy", function(v)
	busy = v and true or false
	render()
end)

function onOpen(_context)
	isOpen = true
	pending = nil
	requestRefresh() -- fresh data lands via the "runs" watcher ~2s later
	render() -- show the cached list instantly meanwhile
end

function onClose()
	isOpen = false
	pending = nil
	expandedId = nil
	editTagsId = nil
	editingOldTag = nil
end

function onRefreshClicked()
	requestRefresh()
end

function onCloseClicked()
	panel.close()
end

function onFilterChange(text)
	filterDraft = text or ""
end

function onFilterSubmit(text)
	applyFilter(text)
end

function onFilterApply()
	applyFilter(filterDraft)
end

function onFilterClear()
	filterGen += 1 -- re-key the input back to empty
	applyFilter("")
end

-- Context-menu dispatch: (activated item id, the value passed as `context` -
-- here the run id). Destructive items expand the card and arm the same inline
-- Yes/No confirm the action buttons use, rather than firing outright: the CLI
-- has no confirm flag, so the panel owns that step either way.
function onRunMenu(itemId, runId)
	if itemId == "open" then
		openInBrowser(runId)
	elseif itemId == "copy" then
		copyToClipboard("Copied", runId)
	elseif itemId == "copyurl" then
		copyRunUrl(runId)
	elseif itemId == "copycommit" then
		local run = runById(runId)
		if run and run.git_commit and run.git_commit ~= "" then
			copyToClipboard("Copied commit", run.git_commit)
		end
	elseif itemId == "logs" then
		openLogs(runId)
	elseif itemId == "tags" then
		expandedId, editTagsId, editingOldTag = runId, runId, nil
		render()
	elseif itemId == "suspend" or itemId == "resume" then
		runAction(itemId, runId)
	elseif itemId == "cancel" or itemId == "delete" then
		expandedId = runId
		pending = { id = runId, action = itemId }
		render()
	end
end

-- Scripting hooks:
--   noctalia msg plugin dani/dart:panel all open <run-id>
--   noctalia msg plugin dani/dart:panel all filter "--states success --limit 5"
-- (an empty filter payload resets to the default query)
function onIpc(event, payload)
	if event == "open" and type(payload) == "string" then
		openInBrowser(payload)
	elseif event == "filter" then
		filterGen += 1
		applyFilter(type(payload) == "string" and payload or "")
	end
end

render()
