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
]]

local DART = noctalia.getConfig("dart_path")
local NU = noctalia.getConfig("nu_path")
local USER = noctalia.getConfig("username")
local LIMIT = noctalia.getConfig("limit") or 30
local POLL = math.max(15, noctalia.getConfig("poll_seconds") or 120)

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

-- Build the poll command. The panel can publish verbatim `dart run filter`
-- args ("custom_filter"); when set they replace the default states query but
-- stay scoped to the configured user. --limit/--username-ss come FIRST so a
-- user-supplied value wins (click keeps the last occurrence of an option).
local function listCmd()
	local custom = noctalia.state.get("custom_filter")
	local filter
	if type(custom) == "string" and custom ~= "" then
		filter = DART .. " run filter --limit " .. tostring(LIMIT) .. " --username-ss " .. USER .. " " .. custom .. " --detailed"
	else
		filter = DART
			.. " run filter --username-ss "
			.. USER
			.. " --states "
			.. STATES
			.. " --limit "
			.. tostring(LIMIT)
			.. " --detailed"
	end
	-- The ~142KB --detailed payload is slimmed by slim.nu before Lua ever
	-- parses it (json.decode runs inside a 25ms callback budget).
	-- Capture-then-pipe instead of pipefail so a dart failure surfaces as a
	-- nonzero exit even though slim.nu is last in the pipeline (POSIX-sh safe).
	-- --stdin feeds the pipe to the script's $in; --no-config-file keeps the
	-- interactive config.nu (starship/atuin/... inits) out of a hot path.
	return 'o=$('
		.. filter
		.. ') || exit $?; printf "%s" "$o" | '
		.. NU
		.. ' --no-config-file --stdin "'
		.. noctalia.pluginDir()
		.. '/slim.nu"'
end

-- Interpret one poll result and publish it.
local function handleResult(res)
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
	-- 20s timeout: far above the ~1.5s p50, far below the 120s browser hang
	-- a stale refresh token would cause. On timeout the whole process group
	-- is killed and handleResult shows the `dart login` hint.
	local ok = noctalia.runAsync(listCmd(), function(res)
		isPolling = false
		noctalia.state.set("busy", false)
		handleResult(res)
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
