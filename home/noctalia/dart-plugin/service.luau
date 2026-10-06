--!nonstrict
--[[
Poller service (entry "poller" of dani/dart): the only entry that runs `dart run
filter`. Widgets get one VM per output, so the one poll loop lives here.

Publishes over noctalia.state:
  "runs"        slimmed run list (fields: slim.nu)
  "pinned_runs" rows of the pinned runs, in pin order (same fields)
  "error"       user-facing error string, nil when healthy
  "busy"        true while a poll is in flight
  "fetched_at"  unix seconds of the last successful poll

Listens on:
  "command"       { op = "refresh", nonce } -> re-poll now (widget/panel ask)
  "custom_filter" verbatim `dart run filter` args from the panel's filter bar
  "muted"         bool; true suspends transition toasts (panel's bell button)
  "pinned"        run ids pinned in the panel, newest first; persisted here

Also toasts every run state transition between two polls (clickable: opens the
run's page).
]]

local common = require("./common.luau")

local DART = noctalia.getConfig("dart_path")
local NU = noctalia.getConfig("nu_path")
local USER = noctalia.getConfig("username")
local LIMIT = noctalia.getConfig("limit") or 100
local POLL = math.max(15, noctalia.getConfig("poll_seconds") or 120)
local NOTIFY = noctalia.getConfig("notify_transitions")
if NOTIFY == nil then
	NOTIFY = true
end

-- The panel's bell button: an instant runtime override of notify_transitions,
-- kept in noctalia.state (resets on a plugin disable/enable).
local muted = noctalia.state.get("muted") and true or false
noctalia.state.watch("muted", function(v)
	muted = v and true or false
end)

-- dart.nvim's active set plus the manual suspend/resume/cancel states: without
-- suspended_manual Resume never shows, and the in-flight states keep a run
-- visible while an action settles.
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

-- `dart run filter <args> | slim.nu`: the ~142KB --detailed payload is slimmed
-- before json.decode, which runs inside a 25ms callback budget. A fixed script
-- with every value passed positionally, never spliced into shell text.
-- Capture-then-pipe so a dart failure still exits nonzero (no pipefail in sh).
-- BROWSER=true: with a stale token dart would open the login page from inside
-- noctalia's cgroup; the poll times out into the `dart login` hint instead.
local SLIM_SCRIPT = 'd=$1 n=$2 s=$3; shift 3; o=$(BROWSER=true "$d" run filter "$@") || exit $?; '
	.. 'printf "%s" "$o" | "$n" --no-config-file --stdin "$s"'
local SLIM_NU = noctalia.pluginDir() .. "/slim.nu"

local function slimmed(args)
	local argv = { "/bin/sh", "-c", SLIM_SCRIPT, "sh", DART, NU, SLIM_NU }
	for _, arg in ipairs(args) do
		argv[#argv + 1] = arg
	end
	return argv
end

-- A custom filter replaces the default states query but stays scoped to the
-- user: --username-ss/--limit come first so a user-supplied value wins (click
-- keeps an option's last occurrence).
local function listArgv()
	local args = { "--username-ss", USER, "--limit", tostring(LIMIT) }
	local custom = customFilter()
	if custom then
		local words, splitErr = common.splitWords(custom)
		if not words then
			return nil, splitErr
		end
		for _, word in ipairs(words) do
			args[#args + 1] = word
		end
	else
		args[#args + 1] = "--states"
		args[#args + 1] = STATES
	end
	args[#args + 1] = "--detailed"
	return slimmed(args)
end

-- ── State transitions ───────────────────────────────────────────────────────
-- A toast per state change between two polls. A run that reached a terminal
-- state drops out of the (active-only) list, so a disappearance triggers one
-- --id-ss re-query to find where it landed. The map persists across restarts;
-- MAX_TOASTS caps the burst after an overnight gap.
local DATA_DIR = noctalia.pluginDataDir() or "/tmp/noctalia-dart"
noctalia.mkdirAll(DATA_DIR)
local SEEN_PATH = DATA_DIR .. "/last_states.json"
local MAX_TOASTS = 5

-- dart's terminal states aren't enumerated anywhere readable: classify by
-- substring.
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
-- noctalia.notify() can't carry actions, so transition toasts go through
-- `notify-send -A default=…`. Only the sender sees ActionInvoked, so notify-send
-- waits and opens the page itself. It is spawned detached (no callback): that
-- takes none of the VM's 8 async slots and no timeout, and it can live as long
-- as the entry stays in the control center's history.
local LOGO = noctalia.pluginDir() .. "/assets/dart-logo.png"
local HAS_NOTIFY_SEND = noctalia.commandExists("notify-send")

-- $1 urgency, $2 icon, $3 title, $4 body, then the browser argv (URL last).
-- notify-send prints the action key only on a click, so only a click opens it.
local NOTIFY_SCRIPT = 'u=$1 i=$2 t=$3 b=$4; shift 4; '
	.. 'a=$(notify-send -a Noctalia -u "$u" -i "$i" -A "default=Open run" "$t" "$b"); '
	.. '[ "$a" = default ] && exec "$@"'

-- `-a Noctalia` makes it look like noctalia.notify's own toasts.
local function clickableNotify(id, title, body, failure)
	local argv = { "/bin/sh", "-c", NOTIFY_SCRIPT, "sh", failure and "critical" or "normal", LOGO, title, body }
	for _, arg in ipairs(common.browserArgv(common.DETAILS_URL .. id)) do
		argv[#argv + 1] = arg
	end
	return noctalia.runAsync(argv)
end

-- "and N more..." summaries: no run to link, but still the dart logo.
local function plainNotify(title, body)
	if HAS_NOTIFY_SEND and noctalia.runAsync({ "notify-send", "-a", "Noctalia", "-u", "normal", "-i", LOGO, title, body }) then
		return
	end
	noctalia.notify(title, body)
end

local function loadSeen()
	local raw = noctalia.readFile(SEEN_PATH)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local parsed = noctalia.json.decode(raw)
	return type(parsed) == "table" and parsed or nil
end

-- nil until a baseline exists: "nothing to compare yet", not "no changes".
local seen = loadSeen()

-- Falls back to a plain toast when notify-send is missing, the id makes no
-- URL, or the spawn is refused. The id gets its own line (a hard break in the
-- toast body) so the ~280 px column doesn't wrap "<id> from → to" mid-way.
local function announce(id, from, to)
	local line = ("%s\n%s → %s"):format(id, tostring(from), tostring(to))
	local failure = isFailureState(to)
	if HAS_NOTIFY_SEND and common.validRunId(id) and clickableNotify(id, "DART", line, failure) then
		return
	end
	if failure then
		noctalia.notifyError("DART", line)
	else
		noctalia.notify("DART", line)
	end
end

-- One --id-ss query (comma-separated) for every run that left the active list;
-- with no --states filter each comes back in the state it landed in. A missing
-- one was deleted and is reported as "gone".
local function resolveVanished(vanished)
	local ids = {}
	for id in pairs(vanished) do
		ids[#ids + 1] = id
	end
	if #ids == 0 then
		return
	end
	local argv = slimmed({ "--id-ss", table.concat(ids, ","), "--limit", tostring(LIMIT), "--detailed" })
	noctalia.runAsync(argv, function(res)
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
				plainNotify("DART", ("and %d more run(s) left the active set"):format(#ids - MAX_TOASTS))
				break
			end
			-- A failed re-query also reports "gone": the run isn't tracked either way.
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

	if not NOTIFY or muted or previous == nil then
		return -- cold start, or muted: take the baseline, say nothing
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
		plainNotify("DART", ("and %d more state change(s)"):format(extra))
	end
	resolveVanished(vanished)
end

-- ── Pinned runs ─────────────────────────────────────────────────────────────
-- A pinned run stays in the panel whatever the filter, and after it leaves the
-- active set. The ids persist across restarts; after each poll the pinned runs
-- the list did not return are re-queried by id, with no --states/--username-ss.
local PINS_PATH = DATA_DIR .. "/pinned.json"

-- Whatever came off the state bus or the file -> a clean id array.
local function pinList(value)
	local ids, dup = {}, {}
	if type(value) == "table" then
		for _, id in ipairs(value) do
			if common.validRunId(id) and not dup[id] then
				dup[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	return ids
end

local function byId(rows)
	local map = {}
	for _, r in ipairs(rows) do
		if type(r) == "table" and r.id then
			map[r.id] = r
		end
	end
	return map
end

local pinnedIds = pinList((noctalia.json.decode(noctalia.readFile(PINS_PATH) or "")))
-- Last row seen per pinned id, seeded from the bus so a hot reload keeps them.
local pinnedRows = byId(noctalia.state.get("pinned_runs") or {})
local lastRuns = noctalia.state.get("runs") or {}
local pinGen = 0 -- drops an id query overtaken by a newer poll's

local function publishPinned()
	local rows = {}
	for _, id in ipairs(pinnedIds) do
		rows[#rows + 1] = pinnedRows[id]
	end
	noctalia.state.set("pinned_runs", rows)
end

-- Called after each poll: a pinned run takes the list's row when it has one,
-- the rest share one --id-ss query (substring match, hence the exact lookup).
-- dart hides deleted runs, so one the query stops returning is kept as "gone"
-- rather than dropped: its card stays until it is unpinned.
local function refreshPinned(runs)
	if #pinnedIds == 0 then
		return
	end
	local listed, missing = byId(runs), {}
	for _, id in ipairs(pinnedIds) do
		if listed[id] then
			pinnedRows[id] = listed[id]
		else
			missing[#missing + 1] = id
		end
	end
	publishPinned()
	if #missing == 0 then
		return
	end
	pinGen += 1
	local gen = pinGen
	local argv = slimmed({ "--id-ss", table.concat(missing, ","), "--limit", tostring(LIMIT), "--detailed" })
	noctalia.runAsync(argv, function(res)
		if gen ~= pinGen or res.timedOut or res.exitCode ~= 0 then
			return -- keep the last rows
		end
		local rows = noctalia.json.decode(res.stdout)
		if type(rows) ~= "table" then
			return
		end
		local landed, stillPinned = byId(rows), {}
		for _, id in ipairs(pinnedIds) do
			stillPinned[id] = true
		end
		for _, id in ipairs(missing) do
			if stillPinned[id] then
				local row = landed[id]
				if not row then
					row = pinnedRows[id] and table.clone(pinnedRows[id]) or { id = id, tags = {}, state_info = "" }
					row.state = "gone"
				end
				pinnedRows[id] = row
			end
		end
		publishPinned()
	end, 20000)
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
	lastRuns = runs
	refreshPinned(runs)
	if diffable then
		diffAndNotify(runs)
	end
end

local isPolling = false
local pendingRefresh = false -- a refresh asked for mid-poll runs right after
local refresh -- fwd decl: the completion callback re-invokes it

refresh = function()
	if isPolling then
		-- Queue, don't drop: the in-flight result may be for a stale query.
		pendingRefresh = true
		return
	end
	local argv, argvErr = listArgv()
	if not argv then
		noctalia.state.set("error", "bad dart filter: " .. tostring(argvErr))
		return
	end
	isPolling = true
	noctalia.state.set("busy", true)
	-- Only the default query is diffable (under a filter, "missing" means
	-- "filtered out"); read at poll start so a filter typed mid-poll counts.
	local diffable = customFilter() == nil
	-- 20s: far above the ~1.5s p50, far below a stale token's 120s hang. On
	-- timeout the process group is killed and the `dart login` hint shows.
	local ok = noctalia.runAsync(argv, function(res)
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

-- update() is the only timer; isPolling keeps ticks from overlapping a slow poll.
noctalia.setUpdateInterval(POLL * 1000)
function update()
	refresh()
end

noctalia.state.watch("command", function(cmd)
	if type(cmd) == "table" and cmd.op == "refresh" then
		refresh()
	end
end)

-- Published before the watch below is registered, so the service's own set
-- doesn't come back through it.
noctalia.state.set("pinned", pinnedIds)
publishPinned()

-- The panel pinned or unpinned a run. A pin clicked in the panel is on a run
-- the service already holds a row for; only an id pinned over IPC needs a poll.
noctalia.state.watch("pinned", function(value)
	pinnedIds = pinList(value)
	local encoded = noctalia.json.encode(pinnedIds, false)
	if encoded then
		noctalia.writeFile(PINS_PATH, encoded)
	end
	local listed, rows, unknown = byId(lastRuns), {}, false
	for _, id in ipairs(pinnedIds) do
		rows[id] = pinnedRows[id] or listed[id]
		unknown = unknown or rows[id] == nil
	end
	pinnedRows = rows
	publishPinned()
	if unknown then
		refresh()
	end
end)

refresh()
