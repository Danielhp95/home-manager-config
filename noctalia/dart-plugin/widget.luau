--!nonstrict
--[[
Bar widget (entry "widget" of dani/dart).

Shows the dart logo plus per-group counts (running / queued / suspended),
with a per-state count tooltip; clicking toggles the run-list panel. Purely event-driven off the
poller service's published state - this entry never calls the dart CLI and
has no update() tick. Note bar widgets get one VM per output, which is why
the polling lives in the singleton service instead of here.
]]

local runs = noctalia.state.get("runs") or {}
local err = noctalia.state.get("error")

local function render()
	-- 18px logo sits comfortably in the 36px capsule bar.
	barWidget.setImage("assets/dart-logo.png", false, 18, 18)

	if err then
		barWidget.setText("!")
		barWidget.setColor("error")
		barWidget.setTooltip("DART error - click for details")
		return
	end

	barWidget.setColor("on_surface")
	-- Group the poller's states into the three badge buckets. Pre-run states
	-- count as queued; every suspend-family state (including the manual
	-- request/in-flight ones) counts as suspended.
	local GROUP = {
		running = "running",
		submitting = "queued",
		submitted = "queued",
		building = "queued",
		queued = "queued",
		preparing = "queued",
		scheduling = "queued",
		suspending = "suspended",
		suspended = "suspended",
		suspend_requested_manual = "suspended",
		suspending_manual = "suspended",
		suspended_manual = "suspended",
		resume_requested_manual = "suspended",
	}
	local counts, groups = {}, { running = 0, queued = 0, suspended = 0 }
	for _, r in ipairs(runs) do
		counts[r.state] = (counts[r.state] or 0) + 1
		local g = GROUP[r.state]
		if g then
			groups[g] += 1
		end
	end
	-- One "<glyph><n>" segment per nonzero group, e.g. "▶2 ⏳1 ⏸3".
	local segments = {}
	if groups.running > 0 then
		segments[#segments + 1] = "▶" .. groups.running
	end
	if groups.queued > 0 then
		segments[#segments + 1] = "⏳" .. groups.queued
	end
	if groups.suspended > 0 then
		segments[#segments + 1] = "⏸" .. groups.suspended
	end
	barWidget.setText(table.concat(segments, " "))

	-- Multi-row tooltip: one "state: count" line per state, sorted.
	local rows = {}
	for state, n in pairs(counts) do
		rows[#rows + 1] = { key = state, value = tostring(n) }
	end
	table.sort(rows, function(a, b)
		return a.key < b.key
	end)
	if #rows > 0 then
		barWidget.setTooltip(rows)
	else
		barWidget.setTooltip("DART: no active runs")
	end
end

noctalia.state.watch("runs", function(v)
	runs = v or {}
	render()
end)
noctalia.state.watch("error", function(v)
	err = v
	render()
end)

function onClick()
	noctalia.togglePanel("dani/dart:panel")
end

-- Scripting hook: `noctalia msg plugin dani/dart:widget focused refresh ""`
-- forces a re-poll through the service's command channel.
function onIpc(event)
	if event == "refresh" then
		noctalia.state.set("command", { op = "refresh", nonce = os.clock() })
	end
end

render()
