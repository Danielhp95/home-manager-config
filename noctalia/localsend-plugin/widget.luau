--!nonstrict
--[[
Bar widget (entry "widget" of dani/localsend).

Shows a send glyph plus the staged-file count, or the live percentage while a
transfer runs. Purely event-driven off the agent service's published state:
this entry never spawns anything and has no update() tick (bar widgets get one
VM per output, so doing work here would multiply it per monitor).

Left click opens the panel; right click opens the drop window directly, so the
common case — drag a file in, send it — never needs the panel at all.
]]

local staged = noctalia.state.get("staged") or {}
local transfer = noctalia.state.get("transfer") or { state = "idle" }
local receive = noctalia.state.get("receive") or { state = "off" }

local function render()
	barWidget.setGlyph("send")

	-- An incoming transfer outranks an outgoing one in the badge.
	local rx = receive.state
	if rx == "waiting" then
		barWidget.setGlyph("download")
		barWidget.setColor("tertiary")
		barWidget.setText("?")
		barWidget.setTooltip(tostring((receive.sender and receive.sender.alias) or "a device") .. " wants to send " .. #(receive.files or {}) .. " file(s)")
		return
	elseif rx == "receiving" then
		barWidget.setGlyph("download")
		barWidget.setColor("primary")
		barWidget.setText(tostring(receive.percent or 0) .. "%")
		local rows = {
			{ key = "from", value = tostring((receive.sender and receive.sender.alias) or "") },
			{ key = "file", value = tostring(receive.name or "") },
		}
		if receive.speed and receive.speed ~= "" then
			rows[#rows + 1] = { key = "speed", value = receive.speed .. "/s" }
		end
		barWidget.setTooltip(rows)
		return
	elseif rx == "error" then
		barWidget.setGlyph("download")
		barWidget.setColor("error")
		barWidget.setText("!")
		barWidget.setTooltip(tostring(receive.message or "receive failed"))
		return
	end

	local state = transfer.state

	if state == "prepare" then
		barWidget.setColor("tertiary")
		barWidget.setText("...")
		barWidget.setTooltip("Waiting for " .. tostring(transfer.device) .. " to accept")
		return
	end

	if state == "uploading" then
		barWidget.setColor("primary")
		barWidget.setText(tostring(transfer.percent or 0) .. "%")
		local rows = {
			{ key = "to", value = tostring(transfer.device) },
			{ key = "file", value = tostring(transfer.name or "") },
		}
		if transfer.speed and transfer.speed ~= "" then
			rows[#rows + 1] = { key = "speed", value = transfer.speed .. "/s" }
		end
		barWidget.setTooltip(rows)
		return
	end

	if state == "error" then
		barWidget.setColor("error")
		barWidget.setText("!")
		barWidget.setTooltip(tostring(transfer.message or "transfer failed"))
		return
	end

	barWidget.setColor("on_surface")
	if #staged > 0 then
		barWidget.setText(tostring(#staged))
		local rows = {}
		for i, f in ipairs(staged) do
			if i > 8 then
				rows[#rows + 1] = { key = "...", value = "+" .. (#staged - 8) .. " more" }
				break
			end
			rows[#rows + 1] = { key = f.name, value = "" }
		end
		barWidget.setTooltip(rows)
	else
		barWidget.setText("")
		barWidget.setTooltip("LocalSend — click to send, right-click to drop files")
	end
end

noctalia.state.watch("staged", function(v)
	staged = v or {}
	render()
end)
noctalia.state.watch("transfer", function(v)
	transfer = v or { state = "idle" }
	render()
end)
noctalia.state.watch("receive", function(v)
	receive = v or { state = "off" }
	render()
end)

function onClick()
	noctalia.togglePanel("dani/localsend:panel")
end

-- Fast path: a drop target without opening the panel first.
function onRightClick()
	noctalia.state.set("command", { op = "drop", nonce = os.clock() })
end

render()
