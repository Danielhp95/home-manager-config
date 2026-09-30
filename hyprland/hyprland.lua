-- Welcome to my hyprland.lua!
--
-- Lua-equivalent of hyprland.conf (Hyprland >= 0.55, hy3 with lua support).
-- Home Manager prepends `hl.plugin.load(<hy3>)` before this file, so
-- hl.plugin.hy3.* and the hy3 config values are available below. Session/env
-- systemd integration is home-manager's own systemd hook (wayland.windowManager
-- .hyprland.systemd, see hyprland/default.nix); greetd launches the compositor
-- via start-hyprland (non_home_manager_config/noctalia-greeter.nix).
--
-- `palette` (every palette.nix colour as "rgb(...)") and `fonts` (the fonts.nix
-- families) are locals that hyprland/default.nix renders ahead of this file,
-- so no hex value or font name is copied in here.
--
-- Reference: https://wiki.hypr.land/Configuring/Start/

-- ─────────────────────────────────────────────────────────────────────────────
-- Monitors
-- ─────────────────────────────────────────────────────────────────────────────
-- Layout lives in kanshi (hyprland/kanshi.nix), not here: it picks a profile
-- for whatever set of screens is plugged in (Dell above the laptop at the desk,
-- any other screen to the laptop's right, laptop alone) and pushes positions
-- over wlr-output-management. Hyprland keeps those as per-output overrides on
-- top of the rule below, so they survive a reload.
--
-- This wildcard is the fallback: it covers the instant before kanshi applies
-- and any setup no profile matches. Monitor rules are matched name > desc > "",
-- so the `present` script's name-keyed mirror rule (SUPER+SHIFT+D) still
-- outranks it, and kanshi's override leaves the mirror setting alone.

-- monitor =,preferred,auto,1
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

-- The built-in panel: 3840x2400 at 16", so scale 2 (1920x1200 logical, the
-- width kanshi's layouts assume). The ICC profile is Lenovo's for this panel
-- (hyprland/default.nix installs it): the panel is P3-wide, so without it
-- sRGB content is stretched over the wider gamut and looks oversaturated.
-- An icc overrides the rule's other colour-management settings (cm, sdr*).
-- kanshi's overrides only touch mode/position/scale, so they keep it.
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "2",
	icc = os.getenv("HOME") .. "/.local/share/icc/TPLCD_41BE_HDR.icm",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- General / Misc / Input / Cursor / Decoration / Animations / Binds / Render
-- ─────────────────────────────────────────────────────────────────────────────
-- Restored on leaving the mouse-cursor submap below, which disables the
-- timeout while active (hl.dsp.cursor.move warps don't reset Hyprland's own
-- cursor-activity timer, so the cursor would otherwise vanish mid-use).
local cursor_inactive_timeout = 5

hl.config({
	misc = {
		disable_hyprland_logo = true,
		exit_window_retains_fullscreen = true, -- closing a fullscreen window makes the next one fullscreen
		enable_swallow = true, -- terminal disappears while the GUI it spawned is open
		swallow_regex = "^kitty",
	},

	general = {
		layout = "hy3",
		resize_on_border = true,
		border_size = 5,
		col = {
			-- Focused window gets the coral rim; unfocused borders stay the
			-- background color, so the 5px border reads as invisible padding
			-- between columns rather than a drawn rim.
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
		kb_layout = "us",
		kb_options = "caps:escape",
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
		-- Hardware cursor plane on the Intel iGPU: moving the cursor costs
		-- zero compositor repaints. Software cursors (the old `true`) forced
		-- a damage+repaint on every cursor move; they're only needed when
		-- the NVIDIA card scans out (the default boot entry) — see the
		-- GPU selection below.
		no_hardware_cursors = false,
	},

	decoration = {
		active_opacity = 0.90,
		inactive_opacity = 0.8,
		fullscreen_opacity = 1.0,
		rounding = 5,
		blur = {
			enabled = true,
			-- 8/4 is expensive on the iGPU (blur renders behind almost every
			-- window given ignore_opacity + the transparency above), but the
			-- lighter 4/2 look was tried and rejected — keep the perception.
			size = 12,
			passes = 3,
			ignore_opacity = true,
		},
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
		-- Hand eligible output commits to the DRM page-flip queue asynchronously
		-- instead of blocking the render loop on each one (Hyprland >= 0.56's
		-- OutputCommitCoordinator). Default is off -- it's new and opt-in. Worth
		-- it here for the same reason borderangle is disabled and hardware
		-- cursors are on: this iGPU has no headroom to spare, and blur behind
		-- almost every window (ignore_opacity + the transparency above) already
		-- makes each frame expensive. If frames start tearing or stuttering,
		-- this is the first knob to put back to false.
		async_commit = true,
	},
})

-- Animations: curves + per-leaf settings
-- `speed` is in deciseconds (4 = 400ms). Tuned so the things you hit dozens of
-- times a day (focus ring, workspace switch, panels) settle in ~300-400ms, and
-- exits are quicker than entrances.
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })
-- borderangle animates the gradient forever: the compositor repaints even
-- when fully idle, so the iGPU never rests. Static gradient instead.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
-- No `layers` leaf means panels, OSDs and notifications inherit the global
-- default (speed 8, 800ms), which is slow for transient UI.
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })
-- The special workspace drops in from the top and retracts back up. The In and
-- Out leaves are split because the style's direction word is applied per leaf,
-- and Hyprland calls Out with the opposite `left` flag from In: "top" on In
-- means enter from above, but the same word on Out would exit downward, so
-- Out uses "bottom" to leave the way it came. Out is 15% slower than a plain
-- 300ms exit (3.45) so the retract doesn't feel clipped.
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
-- The Intel iGPU renders. The NVIDIA card is opened too whenever it is on the
-- bus (the default boot entry), only to scan out the outputs wired to it:
-- HDMI and some USB-C/DP ports, including the one the desk Dell reaches
-- through the dock. That costs ~8W, since the dGPU never runtime-suspends
-- while Hyprland holds it open. The "Roadwarrior" boot entry takes the dGPU
-- off the bus (hardwares/disable_nvidia.nix), so there it is Intel-only.
-- GPU-hungry apps opt in per launch with `nvidia-offload <cmd>`.
-- ─────────────────────────────────────────────────────────────────────────────
-- AQ_DRM_DEVICES is colon-separated, so by-path names (which contain colons)
-- get shattered on parse — resolve them to canonical /dev/dri/cardN first.
-- Card numbering isn't stable across boots, hence resolving at startup.
-- A missing card resolves to nil (`readlink -e`) and is left out of the list.
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
	-- Hardware cursors glitch on NVIDIA scanout; fall back to software
	-- rendering only while the dGPU is open.
	hl.config({ cursor = { no_hardware_cursors = true } })
end
if #drm_devices > 0 then
	hl.env("AQ_DRM_DEVICES", table.concat(drm_devices, ":"))
end
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- ─────────────────────────────────────────────────────────────────────────────
-- Runtime state that has to survive a config reload
--
-- A reload (`hyprctl reload`, SUPER+SHIFT+C below, or a home-manager switch)
-- throws away the Lua VM entirely and re-runs this file from scratch, so
-- anything a running config put in a variable comes back nil. Two pieces of
-- state live *only* in the running compositor and would be lost on every
-- rebuild:
--
--   * the per-workspace scrolling/hy3 toggle (`scrolling_workspaces` below),
--   * the `present` script's mirror rule (hyprland/default.nix).
--
-- Hyprland >= 0.56 fires `config.unload` just before a reload, which is the
-- hook that lets us hand state forward. It can't go through a Lua variable
-- (fresh VM), so it goes through a file.
--
-- Reload vs. logout: `config.unload` fires on shutdown too, immediately
-- followed by `hyprland.shutdown` — so shutdown writes the file and then
-- deletes it again, and a fresh session starts clean (mirroring off, every
-- workspace back on hy3). Only a reload restores. A hard crash can leave a stale file behind and cause one
-- spurious restore on next login; delete it by hand if that ever bites.
-- ─────────────────────────────────────────────────────────────────────────────
local state_dir = os.getenv("HOME") .. "/.local/state/hypr"
local state_path = state_dir .. "/lua-runtime-state"

-- Forward declaration: the layout toggle populates this, and save_state below
-- reads it, but the keybinding section that owns it is further down the file.
local scrolling_workspaces = {} -- workspace id (number) -> true while toggled to scrolling

-- Which output the `present` script has mirroring, or nil. Read live from the
-- compositor rather than trusting a marker the script writes: `present` is only
-- one of the ways a mirror can be set up (hyprctl eval by hand is another), and
-- the compositor is the thing that actually knows. `all = true` because the
-- default list leaves out outputs that are mirroring.
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
			mirror = "eDP-1",
		})
	end
end

hl.on("config.unload", save_state)
hl.on("config.reloaded", restore_state)
-- Fires right after config.unload on exit, so a logout leaves no file behind.
hl.on("hyprland.shutdown", function()
	os.remove(state_path)
end)

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
hl.bind(mod .. " + CONTROL + SHIFT + o", hl.dsp.exec_cmd("wl-ocr"), { description = "OCR screen text" })
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
hl.bind("ALT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher"), { description = "Window switcher" })
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
	local letter = dir:sub(1, 1) -- "left" -> "l", etc. — what hl.dsp.* direction params want
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
hl.bind(mod .. " + CONTROL + t", hy3.lock_tab(), { description = "Lock tab group (hy3)" }) -- lock a tab so it acts as a single node
hl.bind(mod .. " + g", hy3.make_group("tab"), { description = "Make tab group (hy3)" })

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close(), { description = "Close window" })

hl.bind(mod .. " + E", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" }) -- toggle horizontal/vertical split
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(), { description = "Toggle fullscreen" })

-- Special workspaces
hl.bind(mod .. " + Minus", hl.dsp.workspace.toggle_special(), { description = "Toggle special workspace" })
hl.bind(
	mod .. " + SHIFT + Minus",
	hl.dsp.window.move({ workspace = "special" }),
	{ description = "Move window to special workspace" }
)

-- Mouse
-- NOTE: the legacy `hy3:focustab, mouse` (bindn on mouse:272) is a no-op in current
-- hy3 (focus_tab requires a direction or index), so it is intentionally omitted.
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

-- Mouse-cursor submap: vim-style hjkl pointer movement, escape to leave
-- u / d scroll the wheel up / down
-- NOTE: movement uses hl.dsp.cursor.move (native warp), not wlrctl -- wlrctl
-- spawns a whole new Wayland client (connect/negotiate/destroy the
-- zwlr-virtual-pointer-v1 object) on every single repeat tick, which can't
-- keep up with hold-to-repeat and silently drops most of the moves.
hl.bind(mod .. " + M", function()
	-- Native cursor.move warps don't count as "activity" for cursor:inactive_timeout,
	-- so disable it while in this submap or the cursor vanishes mid-use.
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
	-- ydotool wheel units are discrete clicks: REL_WHEEL +y = up.
	-- (wlrctl scroll is broken on Hyprland 0.55: axis events arrive with value120 = 0,
	-- so toolkits ignore them; ydotool injects real uinput events instead.
	-- Must be unmodified keys: holding SHIFT makes apps treat the wheel as horizontal scroll.)
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

-- wl-kbptr (vimium-style mouse control), configured by wl-kbptr/config
-- (hyprland/default.nix).
hl.bind(
	mod .. " + SHIFT + f",
	hl.dsp.exec_cmd("wl-kbptr"),
	{ description = "Keyboard-driven mouse control (wl-kbptr)" }
)
-- Same, but the picked target gets a right click instead of a left one
-- (wl-kbptr/config sets mode_click.button=left; overridden here).
hl.bind(
	mod .. " + CONTROL + SHIFT + f",
	hl.dsp.exec_cmd("wl-kbptr -o mode_click.button=right"),
	{ description = "Keyboard-driven mouse control — right click (wl-kbptr)" }
)
-- Volume / Brightness
-- The nvidia driver registers a phantom `nvidia_0` backlight for its own
-- (disconnected) card0-eDP-2, and bare `brightnessctl` picks it over
-- `intel_backlight` -- which is the device actually wired to the panel
-- (card1-eDP-1, on the iGPU). Writes to nvidia_0 succeed and do nothing, so
-- the device has to be named explicitly.
local backlight = "brightnessctl -d intel_backlight"
-- The keyboard's media keys arrive as bare XF86MonBrightness*/XF86Audio*
-- keysyms (FN is resolved in keyboard firmware), so these binds and the volume
-- ones below take no modifier. `locked` keeps them live on the lock screen;
-- `repeating` lets them key-repeat.
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
-- `volume-all-sinks` (noctalia/default.nix) steps every output at once
-- -- the speakers' and each paired headset's EQ sink, plus any hardware sink
-- without one -- so the keys do the same thing as scrolling the
-- bar's volume pill, instead of only touching whichever sink is default.
local volume = "volume-all-sinks"
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
-- Bare transport keys. These matter more than the SUPER chords above: the Bluetooth
-- headset (WH-1000XM6, via BlueZ AVRCP) and the HP keyboard's consumer-control
-- endpoint both emit these keysyms, and you cannot hold SUPER on a headset -- so
-- with only the SUPER binds, the headphones' play/next/prev buttons did nothing.
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Stop playback" })
-- FN+F8 on the HP chassis, routed through the "HP WMI hotkeys" device.
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, description = "Toggle mic mute" }
)

-- Magnifier (cursor:zoom_factor; `magnify` script, was pypr's magnify plugin)
hl.bind(
	mod .. " + CTRL + Z",
	hl.dsp.exec_cmd("magnify -0.5"),
	{ repeating = true, description = "Zoom out (magnifier)" }
)
hl.bind(
	mod .. " + SHIFT + Z",
	hl.dsp.exec_cmd("magnify +0.5"),
	{ repeating = true, description = "Zoom in (magnifier)" }
)
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("magnify"), { description = "Toggle magnifier zoom" }) -- toggle zoom

-- Projector: mirror this panel onto whatever external display is attached
hl.bind(
	mod .. " + SHIFT + D",
	hl.dsp.exec_cmd("present toggle"),
	{ description = "Present: mirror screen to projector / external display" }
)

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout: hy3 (plugin) config
-- (schema for hy3 built against Hyprland >= 0.55: tabs.colors.*, tabs.radius)
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
				radius = 5, -- was `rounding` in old hy3; renamed to `radius`
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
				-- Don't autotile workspace 9 (where messaging apps live).
				-- (the conf referenced an undefined $messaging_apps variable here)
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
-- noctalia asks the compositor to blur the whole bar rect (ext-background-effect
-- protocol) even where the bar paints nothing, which frosted the transparent gaps
-- between the capsule islands. A protocol blur region bypasses layer-rule blur
-- toggles entirely (Renderer::shouldBlur returns before consulting rules);
-- ignore_alpha is the one rule still honored, and it confines the blur to pixels
-- the bar actually draws. 0.1 rather than 0: a 0 threshold left the gaps blurred.
hl.layer_rule({ name = "noctalia-bar-gap-noblur", match = { namespace = "noctalia-bar-default" }, ignore_alpha = 0.1 })
-- slurp's region overlay ("selection"): without the layers fade-out, the dimmed
-- overlay is already gone when grim captures right after slurp exits (wl-ocr).
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
-- NOTE: the original `pavucontrol` rule had NO match (would apply to every window —
-- almost certainly a bug). A class match is added here so it only targets pavucontrol.
hl.window_rule({
	name = "pavucontrol",
	match = { class = "org.pulseaudio.pavucontrol" },
	size = "1200 900",
	float = true,
	center = true,
})
hl.window_rule({ name = "tile-grayjay", match = { title = "Grayjay" }, tile = true })

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
-- The target of the Super+Shift+O toggle. Nothing carries this tag until that
-- bind puts it there, so the rule is inert by default; `override` on both slots
-- is what lets it beat the global active/inactive opacity in decoration above.
hl.window_rule({
	name = "opacity-opaque-tag",
	match = { tag = "opaque" },
	opacity = "1.0 override 1.0 override",
})

-- Nerdfont names for the noctalia workspaces widget (display = "name")
hl.workspace_rule({ workspace = "1", default_name = "󰈹" }) -- firefox
hl.workspace_rule({ workspace = "2", default_name = "󰆍" }) -- terminal
hl.workspace_rule({ workspace = "9", default_name = "󰇮" }) -- envelope (messaging)

-- No border or rounding on a lone tiled window or a fullscreen one (gaps are
-- already 0 everywhere, see general above).
hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ name = "no-gaps-f1", match = { float = false, workspace = "f[1]" }, border_size = 0, rounding = 0 })

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-tab the messaging workspace (ws9)
--
-- Slack / Telegram / Element are pinned to ws9 by the "messaging-apps" window rule
-- above. We want ws9 to behave as a tabbed workspace, so multiple chat apps stack
-- into tabs instead of tiling side-by-side.
--
-- hy3 has no per-workspace "always tab" setting, so we drive it from events. The
-- changegroup dispatcher acts on the *focused* workspace, and chat apps are often
-- auto-assigned to ws9 in the background while another workspace is focused — so we
-- only convert when ws9 is the active workspace to avoid tabbing the wrong one.
-- autotile is disabled on ws9 (see hy3.autotile.workspaces = "not:9"), so its
-- windows are flat children of the workspace root group and a single
-- `changegroup tab` tabs the whole workspace. Once the root is a tab group, any
-- window that subsequently opens on ws9 is added as a new tab automatically.
-- ─────────────────────────────────────────────────────────────────────────────
local MESSAGING_WS = 9

local function tab_messaging_workspace()
	-- Deferred (after_event, above) so a window that just opened has taken
	-- focus, and is counted, before the check runs.
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
