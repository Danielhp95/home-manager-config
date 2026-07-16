--!nonstrict
--[[
Bar widget (entry "widget" of dani/dart).

Shows the dart logo plus the number of RUNNING runs, with a per-state count
tooltip; clicking toggles the run-list panel. Purely event-driven off the
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
	local counts, running = {}, 0
	for _, r in ipairs(runs) do
		counts[r.state] = (counts[r.state] or 0) + 1
		if r.state == "running" then
			running += 1
		end
	end
	barWidget.setText(running > 0 and tostring(running) or "")

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
