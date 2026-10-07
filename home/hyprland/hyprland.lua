-- Hyprland config in Lua. Home Manager prepends the hy3 plugin load, its
-- session hooks and four locals from ./default.nix: `palette` (the slots, as
-- "rgb(...)" colours), `fonts` (family names), `host` (the built-in panel and
-- the keyboard, hosts/<host>/facts.nix) and `bin` (the scripts the binds run).
--
-- hl.plugin.load only registers hy3: it loads after the first parse, which then
-- reruns this file. On that first pass hl.plugin.hy3 is nil, so everything
-- after the first hy3 call is skipped.
--
-- Reference: https://wiki.hypr.land/Configuring/Start/

-- ─────────────────────────────────────────────────────────────────────────────
-- Monitors
-- ─────────────────────────────────────────────────────────────────────────────
-- Positions come from kanshi (./kanshi.nix), kept by Hyprland as
-- per-output overrides that survive a reload. This wildcard covers the moment
-- before kanshi applies and any setup no profile matches; name-keyed rules such
-- as `present`'s mirror rule outrank it.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

-- 3840x2400 at 16": scale 2 gives the 1920x1200 logical size kanshi assumes.
-- Without the ICC profile (./default.nix) sRGB content looks
-- oversaturated on this P3 panel; it overrides the rule's cm/sdr settings, and
-- kanshi only overrides mode/position/scale.
hl.monitor({
	output = host.panel.output,
	mode = "preferred",
	position = "auto",
	scale = tostring(host.panel.scale),
	icc = host.icc,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- General / Misc / Input / Cursor / Decoration / Animations / Binds / Render
-- ─────────────────────────────────────────────────────────────────────────────
-- The mouse-cursor submap below disables the timeout and restores this value.
local cursor_inactive_timeout = 5

-- A palette colour with an alpha byte: "rgb(15111f)", "cc" -> "rgba(15111fcc)".
local function alpha(colour, aa)
	return (colour:gsub("^rgb%((%x+)%)$", "rgba(%1" .. aa .. ")"))
end

hl.config({
	misc = {
		disable_hyprland_logo = true,
		-- Drawn behind everything, so it shows until the wallpaper is up.
		background_color = palette.bgDeep,
		exit_window_retains_fullscreen = true, -- closing a fullscreen window makes the next one fullscreen
		enable_swallow = true, -- terminal disappears while the GUI it spawned is open
		swallow_regex = "^kitty",
	},

	general = {
		layout = "hy3",
		resize_on_border = true,
		border_size = 5,
		col = {
			-- Unfocused borders match the background, so the 5px border reads as
			-- padding between windows.
			active_border = palette.accent,
			inactive_border = palette.bg,
		},
		gaps_in = 0,
		gaps_out = 0,
		snap = {
			enabled = true,
			window_gap = 25,
			monitor_gap = 10,
			border_overlap = true,
		},
	},

	input = {
		follow_mouse = 1,
		kb_layout = host.keyboard.layout,
		kb_options = host.keyboard.options,
		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification
		touchpad = {
			clickfinger_behavior = true, -- 2 finger right click
			drag_lock = true, -- can lift finger briefly while dragging
			natural_scroll = false,
			disable_while_typing = true,
			scroll_factor = 0.8,
		},
	},

	cursor = {
		inactive_timeout = cursor_inactive_timeout,
		-- Hardware cursor plane: no repaint per cursor move. Software cursors
		-- only while the dGPU is open (GPU selection below).
		no_hardware_cursors = false,
	},

	decoration = {
		active_opacity = 0.90,
		inactive_opacity = 0.8,
		fullscreen_opacity = 1.0,
		rounding = 5,
		blur = {
			enabled = true,
			-- Costly on the iGPU (blur sits behind almost every window), but
			-- lighter settings were rejected on looks.
			size = 12,
			passes = 3,
			ignore_opacity = true,
		},
		-- Floating windows only (the no-shadow-tiled rule below): a soft drop
		-- in the palette's darkest surface instead of the default neutral grey.
		shadow = {
			enabled = true,
			range = 24,
			render_power = 3,
			color = alpha(palette.bgDeep, "cc"),
			offset = { 0, 6 },
		},
	},

	xwayland = {
		-- X11 clients draw 1:1 on eDP-1 instead of being stretched 2x: sharp,
		-- and games see the panel's real 3840x2400. Such a client has to scale
		-- its own UI (Steam: Settings > Interface; Zoom: ../zoom.nix), and its
		-- cursor is half size.
		force_zero_scaling = true,
	},

	animations = {
		enabled = true,
	},

	binds = {
		workspace_back_and_forth = true,
		allow_workspace_cycles = true,
		hide_special_on_workspace_change = true,
	},

	render = {
		-- Commit frames asynchronously instead of blocking the render loop (off
		-- by default). The first knob to turn back off if frames tear or stutter.
		async_commit = true,
	},
})

-- Animations. `speed` is in deciseconds (4 = 400ms); exits are quicker than
-- entrances.
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })
-- borderangle repaints forever, even when idle.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
-- Without it, panels, OSDs and notifications get the global 800ms.
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })
-- The special workspace drops in from the top and retracts upward. Hyprland
-- flips the direction word for Out, so "bottom" there means back up; 3.45 is
-- 15% slower than the other exits so the retract doesn't feel clipped.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4, bezier = "default", style = "slidefadevert top" })
hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 3.45,
	bezier = "default",
	style = "slidefadevert bottom",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Environment variables (GPU selection)
-- The iGPU renders; the NVIDIA card is also opened when present, to scan out
-- the outputs wired to it (HDMI, some USB-C/DP, the desk dock). That keeps the
-- dGPU awake (~8W); the Roadwarrior boot entry takes it off the bus.
-- ─────────────────────────────────────────────────────────────────────────────
-- AQ_DRM_DEVICES is colon-separated and by-path names contain colons, so they
-- are resolved to /dev/dri/cardN (numbering varies per boot); missing is nil.
local function resolve_card(path)
	local p = io.popen("readlink -e " .. path)
	local real = p:read("*l")
	p:close()
	return real
end
local intel_card = resolve_card("/dev/dri/by-path/pci-0000:00:02.0-card")
local nvidia_card = resolve_card("/dev/dri/by-path/pci-0000:01:00.0-card")
local drm_devices = {}
if intel_card then
	drm_devices[#drm_devices + 1] = intel_card
end
if nvidia_card then
	drm_devices[#drm_devices + 1] = nvidia_card
	-- Hardware cursors glitch on NVIDIA scanout.
	hl.config({ cursor = { no_hardware_cursors = true } })
end
if #drm_devices > 0 then
	hl.env("AQ_DRM_DEVICES", table.concat(drm_devices, ":"))
end
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- ─────────────────────────────────────────────────────────────────────────────
-- Runtime state that has to survive a config reload
-- A reload reruns this file in a fresh Lua VM, losing the scrolling-layout
-- toggles and `present`'s mirror rule, so config.unload writes them to a file
-- and config.reloaded restores them. Logout also fires config.unload, then
-- hyprland.shutdown deletes the file; after a crash, a stale file can restore
-- once at the next login.
-- ─────────────────────────────────────────────────────────────────────────────
local state_dir = os.getenv("HOME") .. "/.local/state/hypr"
local state_path = state_dir .. "/lua-runtime-state"

-- Declared here for save_state; the layout toggle bind fills it.
local scrolling_workspaces = {} -- workspace id (number) -> true while toggled to scrolling

-- The output currently mirroring, or nil, read from the compositor.
-- `all = true`: the default list leaves out outputs that are mirroring.
local function mirrored_output()
	for _, mon in ipairs(hl.get_monitors({ all = true })) do
		if mon.is_mirror then
			return mon.name
		end
	end
	return nil
end

local function save_state()
	os.execute("mkdir -p " .. state_dir)
	local f = io.open(state_path, "w")
	if not f then
		return
	end
	local ids = {}
	for id in pairs(scrolling_workspaces) do
		ids[#ids + 1] = tostring(id)
	end
	table.sort(ids)
	f:write("scrolling=", table.concat(ids, ","), "\n")
	f:write("mirror=", mirrored_output() or "", "\n")
	f:close()
end

local function restore_state()
	local f = io.open(state_path, "r")
	if not f then
		return
	end
	local saved = {}
	for line in f:lines() do
		local k, v = line:match("^(%w+)=(.*)$")
		if k then
			saved[k] = v
		end
	end
	f:close()

	for id in (saved.scrolling or ""):gmatch("[^,]+") do
		local n = tonumber(id)
		if n then
			scrolling_workspaces[n] = true
			hl.workspace_rule({ workspace = id, layout = "scrolling" })
		end
	end

	if saved.mirror and saved.mirror ~= "" then
		hl.monitor({
			output = saved.mirror,
			mode = "preferred",
			position = "auto",
			scale = "1",
			mirror = host.panel.output,
		})
	end
end

hl.on("config.unload", save_state)
hl.on("config.reloaded", restore_state)
-- Fires right after config.unload on exit, so a logout leaves no file behind.
hl.on("hyprland.shutdown", function()
	os.remove(state_path)
end)

-- hyprland.start fires inside the first frame's render and window.open before
-- the new window has focus; a dispatch from either runs a tick later instead.
local function after_event(fn)
	hl.timer(fn, { timeout = 1, type = "oneshot" })
end

hl.on("hyprland.start", function()
	after_event(function()
		hl.dispatch(hl.dsp.focus({ workspace = 2 })) -- start on the terminal workspace
	end)
	os.remove(state_path) -- belt and braces: clear anything a crash left behind
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Gestures
-- ─────────────────────────────────────────────────────────────────────────────
hl.gesture({ fingers = 3, direction = "up", scale = 1.5, action = "resize" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "move" })
hl.gesture({ fingers = 4, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 4, direction = "down", action = "float" })
hl.gesture({ fingers = 4, direction = "horizontal", scale = 0.5, action = "workspace" })

-- ─────────────────────────────────────────────────────────────────────────────
-- Keybindings
-- ─────────────────────────────────────────────────────────────────────────────
local mod = "SUPER"
local hy3 = hl.plugin.hy3

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty -1"), { description = "Open terminal" })

hl.bind(mod .. " + D", hl.dsp.exec_cmd("vicinae toggle"), { description = "Open app launcher" })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("choose-bluetooth-device"), { description = "Choose Bluetooth device" })
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("open-paper"), { description = "Open paper search" })
hl.bind(mod .. " + CONTROL + SHIFT + o", hl.dsp.exec_cmd(bin.ocr), { description = "OCR screen text" })
hl.bind(
	mod .. " + SHIFT + o",
	hl.dsp.window.tag({ tag = "opaque", action = "toggle" }),
	{ description = "Toggle window opaque tag" }
)
hl.bind(
	mod .. " + SHIFT + R",
	hl.dsp.exec_cmd("noctalia msg plugin noctalia/screen_recorder:service all toggle"),
	{ description = "Toggle screen recording" }
)
hl.bind(
	mod .. " + SHIFT + S",
	hl.dsp.exec_cmd("noctalia msg screenshot-region"),
	{ description = "Screenshot region (annotate)" }
)
hl.bind(
	mod .. " + A",
	hl.dsp.exec_cmd("noctalia msg screenshot-annotate"),
	{ description = "Screenshot + annotate (full screen)" }
)
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("pavucontrol"), { description = "Open volume mixer" })
hl.bind(
	mod .. " + CONTROL + V",
	hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"),
	{ description = "Open clipboard history" }
)
hl.bind(
	mod .. " + SHIFT + slash",
	hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"),
	{ description = "Open keybind cheatsheet" }
)
-- `hold`: a quick tap (ALT released before the overlay has focus) switches to
-- the previous window and closes it; holding ALT keeps the switcher open.
-- https://docs.noctalia.dev/noctalia/ipc/shell/ ("window-switcher hold")
hl.bind("ALT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher hold"), { description = "Window switcher" })
hl.bind(mod .. " + CONTROL + SHIFT + L", hl.dsp.exec_cmd("noctalia msg session lock"), { description = "Lock screen" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.reload_config(), { description = "Reload Hyprland config" })
hl.bind(mod .. " + b", hl.dsp.exec_cmd("noctalia msg bar-toggle"), { description = "Toggle bar" })
hl.bind(mod .. " + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })

for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), { description = "Focus workspace " .. i })
	hl.bind(
		mod .. " + SHIFT + " .. i,
		hy3.move_to_workspace(tostring(i), { follow = true }),
		{ description = "Move window to workspace " .. i }
	)
end
hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }), { description = "Focus previous workspace" })
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }), { description = "Focus previous empty workspace" })
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }), { description = "Focus next empty workspace" })

local layout_bind = mod .. " + N"

local function active_ws_id()
	local ws = hl.get_active_workspace()
	return ws and ws.id or nil
end

hl.bind(layout_bind, function()
	local id = active_ws_id()
	if not id then
		return
	end
	local layout
	if scrolling_workspaces[id] then
		scrolling_workspaces[id] = nil
		layout = "hy3"
	else
		scrolling_workspaces[id] = true
		layout = "scrolling"
	end
	hl.workspace_rule({ workspace = tostring(id), layout = layout })

	hl.exec_cmd(
		string.format(
			"notify-send -a hyprland -h string:x-canonical-private-synchronous:hypr-layout "
				.. "'Layout: %s' 'Workspace %d — %s to toggle'",
			layout,
			id,
			layout_bind
		)
	)
end, { description = "Toggle workspace layout (hy3 / scrolling)" })

-- Focus / move window (hy3, or Hyprland's native dispatcher on a workspace
-- toggled to scrolling), vim keys and arrows
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(directions) do
	local letter = dir:sub(1, 1) -- hl.dsp.* direction params take "l", "d", ...
	local function move_focus()
		if scrolling_workspaces[active_ws_id()] then
			hl.dispatch(hl.dsp.focus({ direction = letter }))
		else
			hl.dispatch(hy3.move_focus(dir))
		end
	end
	local function move_window()
		if scrolling_workspaces[active_ws_id()] then
			hl.dispatch(hl.dsp.window.move({ direction = letter }))
		else
			hl.dispatch(hy3.move_window(dir))
		end
	end
	hl.bind(mod .. " + " .. key, move_focus, { description = "Focus window (" .. dir .. ")" })
	hl.bind(mod .. " + " .. dir, move_focus, { description = "Focus window (" .. dir .. ")" })
	hl.bind(mod .. " + SHIFT + " .. key, move_window, { description = "Move window (" .. dir .. ")" })
end

hl.bind(mod .. " + SHIFT + Space", hy3.toggle_focus_layer(), { description = "Toggle hy3 focus layer" })
hl.bind(mod .. " + C", hl.dsp.window.center(), { description = "Center floating window" })

hl.bind(mod .. " + s", hy3.set_swallow("toggle"), { description = "Toggle window swallow (hy3)" })

hl.bind(mod .. " + t", hy3.change_group("toggletab"), { description = "Toggle tab group (hy3)" })
hl.bind(mod .. " + CONTROL + t", hy3.lock_tab(), { description = "Lock tab group (hy3)" })
hl.bind(mod .. " + g", hy3.make_group("tab"), { description = "Make tab group (hy3)" })

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close(), { description = "Close window" })

hl.bind(mod .. " + E", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(), { description = "Toggle fullscreen" })

-- Special workspaces
hl.bind(mod .. " + Minus", hl.dsp.workspace.toggle_special(), { description = "Toggle special workspace" })
hl.bind(
	mod .. " + SHIFT + Minus",
	hl.dsp.window.move({ workspace = "special" }),
	{ description = "Move window to special workspace" }
)

-- Mouse. No hy3 focus_tab on click: it needs a direction or an index.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window (mouse)" })

-- Resize submap
hl.bind(mod .. " + R", hl.dsp.submap("resize"), { description = "Enter resize submap" })
hl.define_submap("resize", function()
	local resize = {
		h = { x = -15, y = 0 },
		j = { x = 0, y = 15 },
		k = { x = 0, y = -15 },
		l = { x = 15, y = 0 },
	}
	for key, dir in pairs(directions) do
		local delta = { x = resize[key].x, y = resize[key].y, relative = true }
		hl.bind(key, hl.dsp.window.resize(delta), { repeating = true, description = "Resize window (" .. dir .. ")" })
		hl.bind(dir, hl.dsp.window.resize(delta), { repeating = true, description = "Resize window (" .. dir .. ")" })
	end
	hl.bind("escape", hl.dsp.submap("reset"), { description = "Exit resize submap" })
end)

-- Mouse-cursor submap: hjkl moves the pointer, u / d scroll, escape leaves.
-- Moves use the native warp: wlrctl starts a Wayland client per repeat tick
-- and drops most of the moves.
hl.bind(mod .. " + M", function()
	-- Warps don't count as cursor activity, so the timeout would hide it mid-use.
	hl.config({ cursor = { inactive_timeout = 0 } })
	hl.dispatch(hl.dsp.submap("move"))
end, { description = "Enter mouse-cursor submap" })
hl.define_submap("move", function()
	local deltas = {
		h = { x = -25, y = 0 },
		j = { x = 0, y = 25 },
		k = { x = 0, y = -25 },
		l = { x = 25, y = 0 },
	}
	local function nudge(delta)
		return function()
			local pos = hl.get_cursor_pos()
			hl.dispatch(hl.dsp.cursor.move({ x = pos.x + delta.x, y = pos.y + delta.y }))
		end
	end
	for key, dir in pairs(directions) do
		hl.bind(key, nudge(deltas[key]), { repeating = true, description = "Move cursor (" .. dir .. ")" })
		hl.bind(dir, nudge(deltas[key]), { repeating = true, description = "Move cursor (" .. dir .. ")" })
	end
	-- ydotool, not wlrctl: wlrctl's scroll events carry value120 = 0, which
	-- toolkits ignore. Units are wheel clicks, +y = up. No modifiers: SHIFT
	-- would turn the wheel horizontal.
	hl.bind(
		"u",
		hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y 1.5"),
		{ repeating = true, description = "Scroll wheel up (cursor submap)" }
	)
	hl.bind(
		"d",
		hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y -1.5"),
		{ repeating = true, description = "Scroll wheel down (cursor submap)" }
	)
	hl.bind("space", hl.dsp.exec_cmd("wlrctl pointer click left"), { description = "Left click (cursor submap)" })
	hl.bind("return", hl.dsp.exec_cmd("wlrctl pointer click left"), { description = "Left click (cursor submap)" })
	hl.bind(
		"SHIFT + space",
		hl.dsp.exec_cmd("wlrctl pointer click right"),
		{ description = "Right click (cursor submap)" }
	)
	hl.bind(
		"SHIFT + return",
		hl.dsp.exec_cmd("wlrctl pointer click right"),
		{ description = "Right click (cursor submap)" }
	)
	hl.bind("escape", function()
		hl.config({ cursor = { inactive_timeout = cursor_inactive_timeout } })
		hl.dispatch(hl.dsp.submap("reset"))
	end, { description = "Exit cursor submap" })
end)

-- wl-kbptr (vimium-style mouse control; config in ./wl-kbptr).
hl.bind(
	mod .. " + SHIFT + f",
	hl.dsp.exec_cmd("wl-kbptr"),
	{ description = "Keyboard-driven mouse control (wl-kbptr)" }
)
-- Same, with a right click instead of the config's left one.
hl.bind(
	mod .. " + CONTROL + SHIFT + f",
	hl.dsp.exec_cmd("wl-kbptr -o mode_click.button=right"),
	{ description = "Keyboard-driven mouse control — right click (wl-kbptr)" }
)
hl.bind(
	mod .. " + ALT + f",
	hl.dsp.exec_cmd("wl-kbptr --drag"),
	{ description = "Keyboard-driven mouse control — drag (wl-kbptr)" }
)
-- Volume / Brightness. The media keys arrive as bare XF86 keysyms (FN is
-- resolved in keyboard firmware), so they take no modifier; `locked` keeps them
-- working on the lock screen.
local backlight = "brightnessctl -d " .. host.panel.backlight
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(backlight .. " set 5%-"),
	{ repeating = true, locked = true, description = "Decrease brightness" }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd(backlight .. " set +5%"),
	{ repeating = true, locked = true, description = "Increase brightness" }
)
hl.bind(
	"SHIFT + XF86MonBrightnessDown",
	hl.dsp.exec_cmd(backlight .. " set 1%"),
	{ repeating = false, locked = true, description = "Minimizes brightness" }
)
hl.bind(
	"SHIFT + XF86MonBrightnessUp",
	hl.dsp.exec_cmd(backlight .. " set 100%"),
	{ repeating = false, locked = true, description = "Maxes brightness" }
)
-- volume-all-sinks (pkgs/volume-all-sinks) steps every output sink
-- at once, like scrolling the bar's volume pill, not just the default sink.
local volume = bin.volume
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(volume .. " 5%-"),
	{ repeating = true, locked = true, description = "Decrease volume" }
)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(volume .. " 5%+"),
	{ repeating = true, locked = true, description = "Increase volume" }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(volume .. " mute"), { locked = true, description = "Mute/unmute volume" })
hl.bind(mod .. " + XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { description = "Next track" })
hl.bind(mod .. " + XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { description = "Play/pause" })
hl.bind(mod .. " + XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { description = "Previous track" })
-- Bare transport keys too: the Bluetooth headset (AVRCP) sends these and can't
-- hold SUPER.
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Stop playback" })
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, description = "Toggle mic mute" }
)

-- Magnifier (`magnify` script, ./default.nix)
hl.bind(
	mod .. " + CTRL + Z",
	hl.dsp.exec_cmd(bin.magnify .. " -0.5"),
	{ repeating = true, description = "Zoom out (magnifier)" }
)
hl.bind(
	mod .. " + SHIFT + Z",
	hl.dsp.exec_cmd(bin.magnify .. " +0.5"),
	{ repeating = true, description = "Zoom in (magnifier)" }
)
hl.bind(mod .. " + Z", hl.dsp.exec_cmd(bin.magnify), { description = "Toggle magnifier zoom" })

-- Projector: mirror this panel onto whatever external display is attached
hl.bind(
	mod .. " + SHIFT + D",
	hl.dsp.exec_cmd(bin.present .. " toggle"),
	{ description = "Present: mirror screen to projector / external display" }
)

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout: hy3 (plugin) config
-- ─────────────────────────────────────────────────────────────────────────────
hl.config({
	plugin = {
		hy3 = {
			-- 0 = remove nested group, 1 = keep, 2 = keep only if parent is a tab group
			node_collapse_policy = 2,
			group_inset = 10,
			tab_first_window = false,

			tabs = {
				height = 20,
				padding = 5,
				from_top = false,
				radius = 5,
				render_text = true,
				text_center = true,
				text_font = fonts.mono .. " Bold", -- Pango: trailing Bold = weight
				text_height = 12,
				text_padding = 0,
				border_width = 1,
				-- Mirrors the tmux window pills: the selected tab is a hot coral slab
				-- with dark text, unselected tabs cool to a graphite slab.
				colors = {
					active = palette.accent,
					active_border = palette.accent,
					active_text = palette.bg,
					active_alt_monitor = palette.accentDim,
					active_alt_monitor_border = palette.accentDim,
					active_alt_monitor_text = palette.bg,
					urgent = palette.gold,
					urgent_border = palette.gold,
					urgent_text = palette.bg,
					inactive = palette.surface,
					inactive_border = palette.surface,
					inactive_text = palette.fgSoft,
				},
			},

			autotile = {
				enable = true,
				ephemeral_groups = true,
				trigger_width = 0,
				trigger_height = 0,
				-- Not on ws9: the auto-tab below needs its windows flat.
				workspaces = "not:9",
			},
		},
	},
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Layer rules
-- ─────────────────────────────────────────────────────────────────────────────
hl.layer_rule({ name = "vicinae-blur", match = { namespace = "vicinae" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "vicinae-no-animation", match = { namespace = "vicinae" }, no_anim = true })
-- slurp's region overlay ("selection"): without the layers fade-out, the dimmed
-- overlay is already gone when grim captures right after slurp exits (wl-ocr).
-- wl-kbptr's overlay uses the same namespace, so its hints appear at once too.
hl.layer_rule({ name = "slurp-no-anim", match = { namespace = "^selection$" }, no_anim = true })

-- ─────────────────────────────────────────────────────────────────────────────
-- Window rules
-- ─────────────────────────────────────────────────────────────────────────────
-- Workspace assignments
hl.window_rule({
	name = "firefox-ws1",
	match = { class = "firefox" },
	workspace = 1,
})
hl.window_rule({
	name = "steam-ws6",
	match = { class = "steam" },
	workspace = 6,
})
hl.window_rule({
	name = "spotify-ws8",
	match = { title = "Spotify" },
	workspace = 8,
})
hl.window_rule({
	name = "messaging-apps",
	match = { class = "^(slack|org\\.telegram\\.desktop|element|discord)$" },
	workspace = 9,
})

-- Floating windows
hl.window_rule({ name = "float-general-title", match = { title = "Weather" }, float = true })
hl.window_rule({
	name = "float-general",
	match = {
		class = "^(org\\.pulseaudio\\.pavucontrol|mpv|imv)$",
	},
	float = true,
})
hl.window_rule({ name = "float-zoom-host", match = { initial_title = "zoom" }, float = true })
hl.window_rule({
	name = "pavucontrol",
	match = { class = "org.pulseaudio.pavucontrol" },
	size = "1200 900",
	float = true,
	center = true,
})
hl.window_rule({ name = "tile-grayjay", match = { title = "Grayjay" }, tile = true })
-- The file dialog: yazi in its own kitty, floating like the GTK dialog it
-- replaces. Its size is set on the kitty command line (../yazi/file-chooser.nu).
hl.window_rule({
	name = "file-chooser",
	match = { class = "^file-chooser$" },
	float = true,
	center = true,
})

-- Opacity
hl.window_rule({
	name = "opacity-multiclass",
	match = { class = "^(org\\.pulseaudio\\.pavucontrol|zoom|firefox|mpv|matplotlib)$" },
	opacity = "1.0 override 1.0 override",
})
hl.window_rule({
	name = "opacity-kitty-fullscreen",
	match = { class = "kitty", fullscreen = 1 },
	opacity = "0.9 override 0.9 override",
})
hl.window_rule({
	name = "opacity-weather",
	match = { title = "Weather" },
	opacity = "1.0 override 1.0 override",
})
hl.window_rule({
	name = "opacity-zoom-initial",
	match = { initial_title = "zoom" },
	opacity = "1.0 override 1.0 override",
})
-- Set by the Super+Shift+O tag toggle; `override` beats the global
-- active/inactive opacity.
hl.window_rule({
	name = "opacity-opaque-tag",
	match = { tag = "opaque" },
	opacity = "1.0 override 1.0 override",
})

-- Nerdfont names for the noctalia workspaces widget (display = "name")
hl.workspace_rule({ workspace = "1", default_name = "󰈹" }) -- firefox
hl.workspace_rule({ workspace = "2", default_name = "󰆍" }) -- terminal
hl.workspace_rule({ workspace = "9", default_name = "󰇮" }) -- envelope (messaging)

-- Tiled windows cast no shadow: with no gaps it would fall across the
-- neighbouring window and show through its transparency.
hl.window_rule({ name = "no-shadow-tiled", match = { float = false }, no_shadow = true })

-- No border or rounding on a lone tiled window or a fullscreen one (gaps are
-- already 0 everywhere, see general above).
hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ name = "no-gaps-f1", match = { float = false, workspace = "f[1]" }, border_size = 0, rounding = 0 })

-- Floating windows always show a thin outline: 2px instead of the tiled 5px,
-- and `muted` instead of the background colour while unfocused, so a float
-- never blends into what is under it. `match.focus` limits a rule to the
-- focused (true) or unfocused (false) state.
-- https://wiki.hypr.land/configuring/core/rules/ ("border_color", "border_size")
hl.window_rule({ name = "float-thin-border", match = { float = true }, border_size = 2 })
hl.window_rule({ name = "float-outline-unfocused", match = { float = true, focus = false }, border_color = palette.muted })

-- The window focus would return to on each monitor that is not focused (tagged
-- by the return-window events at the end of this file). A lone tiled window
-- shows nothing: the no-gaps rules above take its border away.
hl.window_rule({
	name = "monitor-return-window",
	match = { tag = "monitor-return", focus = false },
	border_color = palette.accentDim,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-tab the messaging workspace (ws9)
-- hy3 has no per-workspace "always tab", so events tab ws9's root group. The
-- dispatcher acts on the focused workspace, hence only while ws9 is active. With
-- autotile off there, one change_group tabs every window; later ones join as tabs.
-- ─────────────────────────────────────────────────────────────────────────────
local MESSAGING_WS = 9

local function tab_messaging_workspace()
	-- Deferred, so a window that just opened is focused and counted.
	after_event(function()
		local ws = hl.get_active_workspace()
		if ws and ws.id == MESSAGING_WS and ws.windows > 0 then
			hl.dispatch(hy3.change_group("tab"))
		end
	end)
end

hl.on("workspace.active", tab_messaging_workspace) -- switching to ws9
hl.on("window.open", tab_messaging_workspace) -- launching an app on ws9
hl.on("window.move_to_workspace", tab_messaging_workspace) -- dragging an app onto ws9

-- ─────────────────────────────────────────────────────────────────────────────
-- Return window of the unfocused monitors
-- Hyprland has no rule for "the window I would land on if I moved to that
-- monitor", so events keep a `monitor-return` tag on exactly those windows: the
-- last focused window of the visible workspace of every monitor but the focused
-- one. The monitor-return-window rule above colours the tag.
-- ─────────────────────────────────────────────────────────────────────────────
local RETURN_TAG = "monitor-return"

local function tag_return_windows()
	local wanted = {} -- window address -> true
	for _, mon in ipairs(hl.get_monitors()) do
		if not mon.focused then
			local ws = mon.active_special_workspace or mon.active_workspace
			local win = ws and ws.last_window
			if win then
				wanted[win.address] = true
			end
		end
	end
	for _, win in ipairs(hl.get_windows()) do
		local tagged = false
		for _, tag in ipairs(win.tags) do
			if tag == RETURN_TAG then
				tagged = true
			end
		end
		-- "+tag" adds and "-tag" removes; a bare name would toggle.
		if tagged ~= (wanted[win.address] == true) then
			hl.dispatch(hl.dsp.window.tag({
				tag = (tagged and "-" or "+") .. RETURN_TAG,
				window = "address:" .. win.address,
			}))
		end
	end
end

for _, event in ipairs({
	"window.active",
	"monitor.focused",
	"workspace.active",
	"window.close",
	"window.move_to_workspace",
	"workspace.move_to_monitor",
	"monitor.removed",
}) do
	-- Deferred: the focus and workspace state is not updated yet inside the event.
	hl.on(event, function()
		after_event(tag_return_windows)
	end)
end
