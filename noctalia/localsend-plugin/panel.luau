--!nonstrict
--[[
Send panel (entry "panel" of dani/localsend).

Layout: header -> input buttons (drop / pick files / pick folder / clipboard)
-> staged file list -> device list -> transfer strip.

This panel does no IO. service.luau owns discovery, staging and transfers and
publishes "staged" / "devices" / "transfer" / "scanning" / "error" over
noctalia.state; the panel renders those and asks for work over the "command"
channel. That split is what lets a transfer survive the panel being closed,
which matters because prepare-upload blocks until the receiver taps Accept.

Conventions (same as the dart plugin):
- Colors are palette-role tokens so the wallpaper-derived theme applies.
- Every on* prop names a global; per-row handlers are closures installed into
  the script env by cbn().
]]

local DEVICE_GLYPH = {
	mobile = "device-mobile",
	desktop = "device-desktop",
	laptop = "device-laptop",
	web = "world",
	headless = "server",
	server = "server",
}

-- ═══════════════════════════════════════════════════════════ view state ═══

local staged = noctalia.state.get("staged") or {}
local devices = noctalia.state.get("devices") or {}
local transfer = noctalia.state.get("transfer") or { state = "idle" }
local scanning = noctalia.state.get("scanning") or false
local err = noctalia.state.get("error")

local isOpen = true
local lastFingerprint = nil -- device of the in-flight send, for a PIN retry
local pinGen = 0 -- bumped to reseed the (uncontrolled) PIN input

local render -- fwd decl

local env = getfenv()
local function cbn(prefix, i, fn)
	local name = "cb_" .. prefix .. "_" .. i
	env[name] = fn
	return name
end

-- The nonce makes every set() distinct, so the service's watcher always fires
-- even when the same command repeats.
local function cmd(t)
	t.nonce = os.clock()
	noctalia.state.set("command", t)
end

-- ═════════════════════════════════════════════════════════════ helpers ═══

local function humanSize(n)
	n = tonumber(n) or 0
	if n < 1024 then
		return string.format("%d B", n)
	elseif n < 1024 * 1024 then
		return string.format("%.1f KB", n / 1024)
	elseif n < 1024 * 1024 * 1024 then
		return string.format("%.1f MB", n / (1024 * 1024))
	end
	return string.format("%.2f GB", n / (1024 * 1024 * 1024))
end

local function totalStagedBytes()
	local sum = 0
	for _, f in ipairs(staged) do
		sum += tonumber(f.size) or 0
	end
	return sum
end

local function busy()
	return transfer.state == "prepare" or transfer.state == "uploading"
end

-- ══════════════════════════════════════════════════════════════ header ═══

local function header()
	local subtitle
	if #staged == 0 then
		subtitle = "nothing staged"
	else
		subtitle = #staged .. (#staged == 1 and " file" or " files") .. " · " .. humanSize(totalStagedBytes())
	end

	return ui.row({ align = "center", gap = 10 }, {
		ui.glyph({ name = "send", size = 20, color = "primary" }),
		ui.label({ text = "LocalSend", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
		ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 12, flexGrow = 1 }),
		scanning and ui.label({ text = "scanning...", color = "on_surface_variant", fontSize = 12 })
			or ui.spacer({ width = 1 }),
		ui.button({
			glyph = "refresh",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Rescan for devices",
			onClick = "onRescan",
		}),
	})
end

function onRescan()
	cmd({ op = "discover" })
end

-- ═══════════════════════════════════════════════════════ input buttons ═══

local function inputButtons()
	return ui.row({ gap = 8, align = "center" }, {
		ui.button({
			text = "Drop files",
			glyph = "drag-drop",
			variant = "primary",
			controlSize = "sm",
			-- ripdrag cannot accept directories (GTK issue 5348), so say so
			-- here rather than let a dropped folder vanish silently.
			tooltip = "Opens a drop target window. Folders: use Pick folder instead.",
			onClick = "onDrop",
		}),
		ui.button({
			text = "Pick files",
			glyph = "files",
			variant = "secondary",
			controlSize = "sm",
			onClick = "onPickFiles",
		}),
		ui.button({
			text = "Pick folder",
			glyph = "folder",
			variant = "secondary",
			controlSize = "sm",
			tooltip = "Sends every file inside, keeping the folder structure",
			onClick = "onPickFolder",
		}),
		ui.button({
			text = "Clipboard",
			glyph = "clipboard-text",
			variant = "secondary",
			controlSize = "sm",
			tooltip = "Send the clipboard as a text message",
			onClick = "onClip",
		}),
		ui.spacer({ flexGrow = 1 }),
		#staged > 0 and ui.button({
			text = "Clear",
			glyph = "trash",
			variant = "ghost",
			controlSize = "sm",
			onClick = "onClear",
		}) or ui.spacer({ width = 1 }),
	})
end

function onDrop()
	cmd({ op = "drop" })
end
function onPickFiles()
	cmd({ op = "pick", kind = "files" })
end
function onPickFolder()
	cmd({ op = "pick", kind = "folder" })
end
function onClip()
	cmd({ op = "clip" })
end
function onClear()
	cmd({ op = "clear" })
end

-- ════════════════════════════════════════════════════════ staged files ═══

local function stagedRow(f, i)
	return ui.row({ gap = 8, align = "center", paddingH = 6, paddingV = 2 }, {
		ui.glyph({
			name = (f.type or ""):find("^image/") and "photo" or "file",
			size = 14,
			color = "on_surface_variant",
		}),
		ui.label({ text = f.name or "?", color = "on_surface", fontSize = 12, maxLines = 1, flexGrow = 1 }),
		ui.label({ text = humanSize(f.size), color = "on_surface_variant", fontSize = 11 }),
		ui.button({
			glyph = "x",
			glyphSize = 11,
			variant = "ghost",
			controlSize = "sm",
			enabled = not busy(),
			tooltip = "Remove from the queue",
			onClick = cbn("unstage", i, function()
				cmd({ op = "unstage", index = i })
			end),
		}),
	})
end

local function stagedSection()
	if #staged == 0 then
		return ui.row({ paddingH = 6, paddingV = 8 }, {
			ui.label({
				text = "Drop or pick files to queue them for sending.",
				color = "on_surface_variant",
				fontSize = 12,
			}),
		})
	end
	local rows = {}
	for i, f in ipairs(staged) do
		rows[#rows + 1] = stagedRow(f, i)
	end
	return ui.scroll({ height = 132, gap = 2 }, rows)
end

-- ═════════════════════════════════════════════════════════════ devices ═══

local function deviceRow(d, i)
	local glyph = DEVICE_GLYPH[d.deviceType or ""] or "device-desktop"
	local sub = tostring(d.ip or "?")
	if not d.online then
		sub = sub .. " · offline"
	end

	local bits = {
		ui.glyph({ name = glyph, size = 18, color = d.online and "primary" or "on_surface_variant" }),
		ui.column({ gap = 0, flexGrow = 1 }, {
			ui.label({
				text = d.alias or "unknown",
				color = d.online and "on_surface" or "on_surface_variant",
				fontSize = 13,
				fontWeight = "semibold",
				maxLines = 1,
			}),
			ui.label({ text = sub, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
		}),
		ui.button({
			glyph = d.fav and "star-filled" or "star",
			glyphSize = 13,
			variant = "ghost",
			controlSize = "sm",
			tooltip = d.fav and "Unpin this device" or "Pin this device (kept while offline)",
			onClick = cbn("fav", i, function()
				cmd({ op = "fav", fingerprint = d.fingerprint, on = not d.fav })
			end),
		}),
		ui.button({
			text = "Send",
			glyph = "send",
			variant = "secondary",
			controlSize = "sm",
			enabled = (#staged > 0) and not busy(),
			tooltip = #staged == 0 and "Stage some files first" or ("Send to " .. tostring(d.alias)),
			onClick = cbn("send", i, function()
				lastFingerprint = d.fingerprint
				cmd({ op = "send", fingerprint = d.fingerprint })
			end),
		}),
	}

	return ui.row({ gap = 8, align = "center", paddingH = 6, paddingV = 4, radius = 8 }, bits)
end

local function deviceSection()
	if #devices == 0 then
		local msg = scanning and "Looking for devices..."
			or "No devices found. Open LocalSend on the other device and rescan."
		return ui.column({ gap = 6, paddingH = 6, paddingV = 10 }, {
			ui.label({ text = msg, color = "on_surface_variant", fontSize = 12 }),
		})
	end
	local rows = {}
	for i, d in ipairs(devices) do
		rows[#rows + 1] = deviceRow(d, i)
	end
	return ui.scroll({ flexGrow = 1, gap = 2 }, rows)
end

-- ════════════════════════════════════════════════════════════ transfer ═══

function onCancelTransfer()
	cmd({ op = "cancel" })
end
function onDismiss()
	cmd({ op = "dismiss" })
end
function onPinSubmit(text)
	pinGen += 1
	if lastFingerprint then
		cmd({ op = "send", fingerprint = lastFingerprint, pin = noctalia.string.trim(text) })
	end
end

local function transferStrip()
	local state = transfer.state
	if state == nil or state == "idle" then
		return nil
	end

	if state == "prepare" then
		return ui.row({ gap = 10, align = "center", paddingH = 6 }, {
			ui.glyph({ name = "clock", size = 14, color = "tertiary" }),
			ui.label({
				text = "Waiting for " .. tostring(transfer.device) .. " to accept...",
				color = "on_surface",
				fontSize = 12,
				flexGrow = 1,
			}),
			ui.button({
				text = "Cancel",
				variant = "ghost",
				controlSize = "sm",
				onClick = "onCancelTransfer",
			}),
		})
	end

	if state == "uploading" then
		local pct = tonumber(transfer.percent) or 0
		local label = tostring(transfer.name or "")
		if transfer.total and tonumber(transfer.total) and tonumber(transfer.total) > 1 then
			label = string.format("%s (%d/%d)", label, (tonumber(transfer.index) or 0) + 1, tonumber(transfer.total))
		end
		local speed = (transfer.speed and transfer.speed ~= "") and (transfer.speed .. "/s") or ""
		return ui.column({ gap = 4, paddingH = 6 }, {
			ui.row({ gap = 8, align = "center" }, {
				ui.label({ text = label, color = "on_surface", fontSize = 12, maxLines = 1, flexGrow = 1 }),
				ui.label({ text = speed, color = "on_surface_variant", fontSize = 11 }),
				ui.label({ text = pct .. "%", color = "primary", fontSize = 11, fontWeight = "semibold" }),
				ui.button({
					text = "Cancel",
					variant = "ghost",
					controlSize = "sm",
					onClick = "onCancelTransfer",
				}),
			}),
			ui.progress({
				progress = pct / 100,
				fill = "primary",
				track = "surface_variant",
				height = 6,
				radius = 3,
			}),
		})
	end

	-- A 401 is a prompt, not a dead end: offer the PIN inline.
	if state == "error" and transfer.needsPin then
		return ui.row({ gap = 8, align = "center", paddingH = 6 }, {
			ui.glyph({ name = "lock", size = 14, color = "tertiary" }),
			ui.label({ text = "PIN required", color = "on_surface", fontSize = 12 }),
			ui.input({
				key = "pin-" .. tostring(pinGen),
				placeholder = "PIN, then Enter",
				fontSize = 12,
				controlSize = "sm",
				width = 160,
				password = true,
				onSubmit = "onPinSubmit",
			}),
			ui.spacer({ flexGrow = 1 }),
			ui.button({ text = "Dismiss", variant = "ghost", controlSize = "sm", onClick = "onDismiss" }),
		})
	end

	local color = (state == "done") and "primary" or (state == "error") and "error" or "on_surface_variant"
	local glyph = (state == "done") and "check" or (state == "error") and "alert-triangle" or "circle-x"
	return ui.row({ gap = 8, align = "center", paddingH = 6 }, {
		ui.glyph({ name = glyph, size = 14, color = color }),
		ui.label({
			text = tostring(transfer.message or state),
			color = color,
			fontSize = 12,
			maxLines = 2,
			flexGrow = 1,
		}),
		ui.button({ text = "Dismiss", variant = "ghost", controlSize = "sm", onClick = "onDismiss" }),
	})
end

-- ══════════════════════════════════════════════════════════════ render ═══

render = function()
	if not isOpen then
		return
	end

	local children = {
		header(),
		ui.separator({ spacing = 4, color = "outline/0.4" }),
		inputButtons(),
		stagedSection(),
		ui.separator({ spacing = 4, color = "outline/0.4" }),
		ui.row({ gap = 8, align = "center", paddingH = 6 }, {
			ui.glyph({ name = "wifi", size = 14, color = "on_surface_variant" }),
			ui.label({ text = "Nearby devices", color = "on_surface_variant", fontSize = 12, fontWeight = "semibold" }),
		}),
		deviceSection(),
	}

	if err then
		children[#children + 1] = ui.row({ gap = 6, align = "center", paddingH = 6 }, {
			ui.glyph({ name = "alert-triangle", size = 13, color = "error" }),
			ui.label({ text = tostring(err), color = "error", fontSize = 11, maxLines = 2 }),
		})
	end

	local strip = transferStrip()
	if strip then
		children[#children + 1] = ui.separator({ spacing = 4, color = "outline/0.4" })
		children[#children + 1] = strip
	end

	panel.render(ui.column({ gap = 8, padding = 12, flexGrow = 1 }, children))
end

-- ════════════════════════════════════════════════════════════ watchers ═══

noctalia.state.watch("staged", function(v)
	staged = v or {}
	render()
end)
noctalia.state.watch("devices", function(v)
	devices = v or {}
	render()
end)
noctalia.state.watch("transfer", function(v)
	transfer = v or { state = "idle" }
	render()
end)
noctalia.state.watch("scanning", function(v)
	scanning = v or false
	render()
end)
noctalia.state.watch("error", function(v)
	err = v
	render()
end)

function onOpen()
	isOpen = true
	-- Devices come and go; a sweep is ~1s, so refresh on every open rather
	-- than keeping a background timer running.
	cmd({ op = "discover" })
	render()
end

function onClose()
	isOpen = false
end

-- Scripting hook, e.g.
--   noctalia msg plugin dani/localsend:panel all drop ""
--   noctalia msg plugin dani/localsend:panel all discover ""
function onIpc(event, payload)
	if event == "drop" then
		cmd({ op = "drop" })
	elseif event == "discover" then
		cmd({ op = "discover" })
	elseif event == "clip" then
		cmd({ op = "clip" })
	elseif event == "send" and payload and payload ~= "" then
		lastFingerprint = payload
		cmd({ op = "send", fingerprint = payload })
	end
end

render()
