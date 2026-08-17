--!nonstrict
--[[
Poller service (entry "poller" of dani/dart).

The ONLY entry that runs `dart run filter`. Widget entries are per-output
VMs, so a singleton service entry guarantees exactly one poll loop no matter
how many monitors are connected.

Publishes over noctalia.state (shared by all entries of this plugin):
  "runs"       slimmed run list (see slim.nu for the exact fields)
  "error"      user-facing error string, nil when healthy
  "busy"       true while a poll is in flight
  "fetched_at" unix seconds of the last successful poll

Listens on:
  "command"       { op = "refresh", nonce } -> re-poll now (widget/panel ask)
  "custom_filter" verbatim `dart run filter` args from the panel's filter bar

Also raises a notification on every run state transition between two polls —
see the "State transitions" block below. Those toasts are clickable (click →
the run's page in $BROWSER); see the "Clickable toasts" block for why they go
through notify-send rather than noctalia.notify.
]]

local DART = noctalia.getConfig("dart_path")
local NU = noctalia.getConfig("nu_path")
local USER = noctalia.getConfig("username")
local LIMIT = noctalia.getConfig("limit") or 100
local POLL = math.max(15, noctalia.getConfig("poll_seconds") or 120)
local NOTIFY = noctalia.getConfig("notify_transitions")
if NOTIFY == nil then
	NOTIFY = true
end

-- Default query states: dart.nvim's active set, extended with the manual
-- suspend/resume/cancel in-flight states - without suspended_manual the
-- panel's Resume button could never appear, and the in-flight states keep a
-- run visible while an action settles.
local STATES = table.concat({
	"submitting",
	"submitted",
	"building",
	"queued",
	"preparing",
	"scheduling",
	"running",
	"suspending",
	"suspended",
	"suspend_requested_manual",
	"suspending_manual",
	"suspended_manual",
	"resume_requested_manual",
	"cancel_requested",
	"canceling",
}, ",")

-- Verbatim `dart run filter` args published by the panel's filter bar, or nil
-- when the default query is in force.
local function customFilter()
	local custom = noctalia.state.get("custom_filter")
	if type(custom) == "string" and custom ~= "" then
		return custom
	end
	return nil
end

-- `dart run filter <args>` piped through slim.nu. The ~142KB --detailed payload
-- is slimmed before Lua ever parses it (json.decode runs inside a 25ms callback
-- budget). Capture-then-pipe instead of pipefail so a dart failure surfaces as a
-- nonzero exit even though slim.nu is last in the pipeline (POSIX-sh safe).
-- --stdin feeds the pipe to the script's $in; --no-config-file keeps the
-- interactive config.nu (starship/atuin/... inits) out of a hot path.
local function slimmed(args)
	return 'o=$('
		.. DART
		.. " run filter "
		.. args
		.. ') || exit $?; printf "%s" "$o" | '
		.. NU
		.. ' --no-config-file --stdin "'
		.. noctalia.pluginDir()
		.. '/slim.nu"'
end

-- Build the poll command. A custom filter replaces the default states query but
-- stays scoped to the configured user. --limit/--username-ss come FIRST so a
-- user-supplied value wins (click keeps the last occurrence of an option).
local function listCmd()
	local custom = customFilter()
	if custom then
		return slimmed("--limit " .. tostring(LIMIT) .. " --username-ss " .. USER .. " " .. custom .. " --detailed")
	end
	return slimmed("--username-ss " .. USER .. " --states " .. STATES .. " --limit " .. tostring(LIMIT) .. " --detailed")
end

-- ── State transitions ───────────────────────────────────────────────────────
-- Every poll already knows each run's state; what is worth a notification is
-- the *edge* between two polls. Two kinds exist and only one is visible in the
-- run list:
--
--   queued -> running        both polls list the run, the state differs
--   running -> <terminal>    the run drops out of the list entirely, because
--                            the default query is scoped to the active STATES
--
-- The second is the one that actually matters ("did the batch finish while I
-- was away"), so a disappearance triggers one targeted --id-ss re-query with no
-- --states filter to find out where the run landed.
--
-- The map is persisted, so a transition that happened while the shell was down
-- still gets reported on the first poll after it comes back. MAX_TOASTS caps
-- the burst that follows an overnight gap.
local DATA_DIR = noctalia.pluginDataDir() or "/tmp/noctalia-dart"
noctalia.mkdirAll(DATA_DIR)
local SEEN_PATH = DATA_DIR .. "/last_states.json"
local MAX_TOASTS = 5

-- dart's terminal states are not enumerated anywhere this plugin can read, so
-- classify by substring: anything that reads like a failure gets the error
-- styling, everything else a plain notification.
local function isFailureState(state)
	local s = tostring(state):lower()
	for _, needle in ipairs({ "fail", "error", "cancel", "kill", "abort" }) do
		if s:find(needle, 1, true) then
			return true
		end
	end
	return false
end

-- ── Clickable toasts ────────────────────────────────────────────────────────
-- noctalia.notify() raises a notification with no actions, and noctalia's toast
-- only reacts to a left-click when actions[0] == "default"
-- (shell/notification/notification_toast.cpp), so a plugin cannot make its own
-- notifications clickable through the Luau API at all. Transition toasts
-- therefore go out over D-Bus via `notify-send -A default=…` instead.
--
-- Only the sending process receives ActionInvoked, so notify-send has to
-- outlive the toast and open the run page itself. It is spawned DETACHED
-- (runAsync with no callback): a detached spawn neither consumes one of the
-- VM's 8 async-command slots nor takes a timeout, so a burst of these can sit
-- waiting without starving the poller. They are not short-lived either —
-- noctalia defers NotificationClosed for an actionable notification that only
-- expired, which is what keeps the control center's history entry clickable
-- too; the process is reaped when that entry is dismissed or ages out.
local DETAILS_URL = "https://dart.platform.research.sony/en/details/" -- as in panel.luau
local BROWSER = noctalia.getenv("BROWSER") or "xdg-open"
local LOGO = noctalia.pluginDir() .. "/assets/dart-logo.png"
local HAS_NOTIFY_SEND = noctalia.commandExists("notify-send")

-- Same guard as the panel: a run id is interpolated into /bin/sh, so anything
-- that is not alphanumeric-with-dashes falls back to a plain toast.
local function validRunId(id)
	return type(id) == "string" and id:match("^[%w%-]+$") ~= nil
end

local function sq(s) -- POSIX single-quoting for /bin/sh -c
	return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

-- `-a Noctalia` keeps the toast visually identical to noctalia.notify's, which
-- is what addInternal() stamps as the app name.
local function clickableNotify(id, title, body, failure)
	return noctalia.runAsync(table.concat({
		"a=$(notify-send -a Noctalia -u ",
		failure and "critical" or "normal",
		" -i ",
		sq(LOGO),
		" -A ",
		sq("default=Open run"),
		" ",
		sq(title),
		" ",
		sq(body),
		")",
		-- stdout carries the action key when the toast is clicked and is empty
		-- when it just expires, so the browser only ever starts on a click.
		'; [ "$a" = default ] && exec ',
		BROWSER,
		" ",
		sq(DETAILS_URL .. id),
	}))
end

local function loadSeen()
	local raw = noctalia.readFile(SEEN_PATH)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local parsed = noctalia.json.decode(raw)
	return type(parsed) == "table" and parsed or nil
end

-- nil until a baseline exists. Distinguishes "nothing to compare against yet"
-- (say nothing) from "compared, and nothing changed".
local seen = loadSeen()

-- Clicking the toast opens the run's page, the same URL the panel's open button
-- uses. Falls back to a plain (unclickable) toast when notify-send is missing,
-- the id is unsafe to interpolate, or the spawn is refused.
--
-- The newline is a hard break, not a suggestion: the toast body is laid out
-- with single_paragraph_mode off (render/text/cairo_text_renderer.cpp), so
-- Pango starts a new paragraph at '\n'. It stays one break through the whole
-- pipeline — sanitizeMarkup() at the D-Bus ingress only touches tags and
-- entities. Keeping the id on its own line is what stops the ~280 px body
-- column from word-wrapping "<id> from → to" mid-transition; both halves now
-- fit their line, and the toast's 3-line body budget leaves one to spare.
local function announce(id, from, to)
	local line = ("%s\n%s → %s"):format(id, tostring(from), tostring(to))
	local failure = isFailureState(to)
	if HAS_NOTIFY_SEND and validRunId(id) and clickableNotify(id, "DART", line, failure) then
		return
	end
	if failure then
		noctalia.notifyError("DART", line)
	else
		noctalia.notify("DART", line)
	end
end

-- Resolve runs that dropped out of the active query. One command for the whole
-- batch: --id-ss takes a comma-separated list, and with no --states filter a run
-- comes back carrying the state it landed in. A run that comes back missing was
-- deleted (dart's default data-state filter hides those) and is reported as such.
local function resolveVanished(vanished)
	local ids = {}
	for id in pairs(vanished) do
		ids[#ids + 1] = id
	end
	if #ids == 0 then
		return
	end
	local cmd = slimmed("--id-ss " .. table.concat(ids, ",") .. " --limit " .. tostring(LIMIT) .. " --detailed")
	noctalia.runAsync(cmd, function(res)
		local landed = {}
		if not res.timedOut and res.exitCode == 0 then
			local rows = noctalia.json.decode(res.stdout)
			if type(rows) == "table" then
				for _, r in ipairs(rows) do
					if type(r) == "table" and r.id then
						landed[r.id] = r.state
					end
				end
			end
		end
		for i, id in ipairs(ids) do
			if i > MAX_TOASTS then
				noctalia.notify("DART", ("and %d more run(s) left the active set"):format(#ids - MAX_TOASTS))
				break
			end
			-- No row and no error means the run is genuinely gone; a failed
			-- re-query is reported the same way rather than silently dropped,
			-- since either way the run is no longer being tracked.
			announce(id, vanished[id], landed[id] or "gone")
		end
	end, 20000)
end

local function diffAndNotify(runs)
	local current = {}
	for _, r in ipairs(runs) do
		if type(r) == "table" and r.id then
			current[r.id] = r.state
		end
	end

	local previous = seen
	seen = current
	local encoded = noctalia.json.encode(current, false)
	if encoded then
		noctalia.writeFile(SEEN_PATH, encoded)
	end

	if not NOTIFY or previous == nil then
		return -- cold start: take the baseline, say nothing
	end

	local shown, extra, vanished = 0, 0, {}
	for id, was in pairs(previous) do
		local now = current[id]
		if now == nil then
			vanished[id] = was
		elseif now ~= was then
			shown = shown + 1
			if shown <= MAX_TOASTS then
				announce(id, was, now)
			else
				extra = extra + 1
			end
		end
	end
	if extra > 0 then
		noctalia.notify("DART", ("and %d more state change(s)"):format(extra))
	end
	resolveVanished(vanished)
end

-- Interpret one poll result and publish it.
local function handleResult(res, diffable)
	if res.timedOut then
		noctalia.state.set("error", "dart timed out - auth may be stale; run `dart login` in a terminal")
		return
	end
	if res.exitCode ~= 0 then
		local hint = ""
		if
			res.stderr:find("Failed to refresh token", 1, true)
			or res.stderr:find("Full flow required", 1, true)
			or res.stderr:find("re-login", 1, true)
		then
			hint = " - run `dart login` in a terminal"
		end
		noctalia.state.set("error", ("dart exited %d%s\n%s"):format(res.exitCode, hint, res.stderr:sub(-300)))
		return
	end
	local runs, err = noctalia.json.decode(res.stdout)
	if type(runs) ~= "table" then
		noctalia.state.set("error", "bad JSON from dart: " .. tostring(err))
		return
	end
	noctalia.state.set("error", nil)
	noctalia.state.set("runs", runs)
	noctalia.state.set("fetched_at", os.time())
	if diffable then
		diffAndNotify(runs)
	end
end

local isPolling = false
local pendingRefresh = false -- a refresh asked for mid-poll runs right after
local refresh -- fwd decl: the completion callback re-invokes it

refresh = function()
	if isPolling then
		-- Queue instead of drop: the in-flight result would be stale for a
		-- just-changed query (e.g. a filter applied right after panel-open
		-- kicked off the default poll).
		pendingRefresh = true
		return
	end
	isPolling = true
	noctalia.state.set("busy", true)
	-- Captured at poll start, not in the callback: only the default query is
	-- diffable — under a panel filter, "missing from the list" means "excluded
	-- by the filter", which would fire a finished-toast for every run the filter
	-- drops. Reading it here rather than on completion also covers the user
	-- typing a filter while this poll is in flight.
	local diffable = customFilter() == nil
	-- 20s timeout: far above the ~1.5s p50, far below the 120s browser hang
	-- a stale refresh token would cause. On timeout the whole process group
	-- is killed and handleResult shows the `dart login` hint.
	local ok = noctalia.runAsync(listCmd(), function(res)
		isPolling = false
		noctalia.state.set("busy", false)
		handleResult(res, diffable)
		if pendingRefresh then
			pendingRefresh = false
			refresh()
		end
	end, 20000)
	if not ok then -- async-command slots exhausted; retry on the next tick
		isPolling = false
		noctalia.state.set("busy", false)
	end
end

-- update() is the only timer noctalia offers; the isPolling guard keeps
-- ticks from overlapping a slow poll (callbacks are serialized per-VM).
noctalia.setUpdateInterval(POLL * 1000)
function update()
	refresh()
end

noctalia.state.watch("command", function(cmd)
	if type(cmd) == "table" and cmd.op == "refresh" then
		refresh()
	end
end)

refresh()
