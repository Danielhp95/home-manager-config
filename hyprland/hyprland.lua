-- Welcome to my hyprland.lua!
--
-- Lua-equivalent of hyprland.conf (Hyprland >= 0.55, hy3 with lua support).
-- Home Manager prepends `hl.plugin.load(<hy3>)` before this file, so
-- hl.plugin.hy3.* and the hy3 config values are available below. Session/env
-- systemd integration is home-manager's own systemd hook (wayland.windowManager
-- .hyprland.systemd, see hyprland/default.nix); greetd launches the compositor
-- via start-hyprland (tuigreet.nix).
--
-- Reference: https://wiki.hypr.land/Configuring/Start/

-- ─────────────────────────────────────────────────────────────────────────────
-- Ember theme colors (was: source = colors-hyprland.conf)
-- ─────────────────────────────────────────────────────────────────────────────
local background = "rgb(1c1b19)"
local foreground = "rgb(d8d0c0)"
local color0 = "rgb(1c1b19)" -- black  / bg0
local color1 = "rgb(e08060)" -- red    / coral
local color2 = "rgb(8a9868)" -- green  / olive
local color3 = "rgb(c8b468)" -- yellow / gold (hy3 urgent tabs ride this)
local color4 = "rgb(ef7f38)" -- blue   / steel (magma orange since 2026-08)
local color5 = "rgb(988090)" -- magenta/ mauve
local color6 = "rgb(7aa88a)" -- cyan   / sage
local color7 = "rgb(d8d0c0)" -- white  / fg0

-- Ember ramp, shared with the tmux status bar (tmux/tmux.conf). Cold to blazing:
-- the focused thing sits at full coral, everything unfocused cools toward ash and
-- graphite. Keep these in sync with the @color_ember* vars in tmux.conf.
local ash = "rgb(8a5a3c)" -- burnt umber, the rim on a cooled tab
local ember_dim = "rgb(b8654c)" -- banked coral
local ember = "rgb(e08060)" -- coral (== color1)
local ember_hot = "rgb(ff8f66)" -- blazing coral
local surface = "rgb(2c2b29)" -- graphite slab (tmux @color_bg1)
local surface_hi = "rgb(3c3b39)" -- lifted graphite (tmux @color_bg2)
local fg_dim = "rgb(b8b0a0)" -- secondary text (tmux @color_fg1)

-- ─────────────────────────────────────────────────────────────────────────────
-- Monitors
-- ─────────────────────────────────────────────────────────────────────────────
-- Desk layout: the two HP panels side by side on top, laptop tucked underneath
-- straddling the seam between them.
--
--        0        2560      5120
--   0    ┌─────────┬─────────┐
--        │  DP-1   │ HDMI-A-1│   2× HP E27q G4, 2560x1440
--   1440 └───┬─────┴───┬─────┘
--            │  eDP-1  │           1920x1200@165, at 1774x1440
--   2640     └─────────┘
--
-- The two HPs are the same model, so they're matched on `desc:` *including the
-- serial* — that keeps each panel on its own side no matter which port it lands
-- on. Only positions are pinned; `preferred` still picks each panel's native
-- mode (165Hz on the laptop, 1440p60 on the HPs).
--
-- Rules are matched name > desc > "" (the wildcard is a fallback for any display
-- not listed here, e.g. a projector), so this ordering is safe.
--
-- A projector therefore lands here as an *extended* display. There is no mirror
-- rule on purpose: mirroring is on demand via the `present` script (SUPER+SHIFT+D),
-- which registers a name-keyed rule at runtime that outranks the wildcard below.

-- monitor =,preferred,auto,1
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

-- Left HP (serial ...JD)
hl.monitor({
	output = "desc:HP Inc. HP E27q G4 CNK22910JD",
	mode = "preferred",
	position = "0x0",
	scale = "1",
})

-- Right HP (serial ...JM)
hl.monitor({
	output = "desc:HP Inc. HP E27q G4 CNK22910JM",
	mode = "preferred",
	position = "2560x0",
	scale = "1",
})

-- Built-in panel, below and between the two HPs. 1774 rather than a dead-centre
-- 1600 — it overlaps both HPs' bottom edges either way, so the cursor can cross.
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "1774x1440",
	scale = "1",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- General / Misc / Input / Cursor / Decoration / Animations / Binds / dwindle
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
			-- between columns rather than a drawn rim. (This used to be
			-- borderless on both — focus via the hy3 tab bar only — but the
			-- active glow came back by request.)
			active_border = ember,
			inactive_border = background,
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
		-- the NVIDIA card scans out — see the dgpu-hdmi branch below.
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

	dwindle = {
		preserve_split = true,
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
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
-- borderangle animates the gradient forever: the compositor repaints even
-- when fully idle, so the iGPU never rests. Static gradient instead.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
-- The special workspace drops in from the top and retracts back up. The In and
-- Out leaves are split because the style's direction word is applied per leaf,
-- and Hyprland calls Out with the opposite `left` flag from In: "top" on In
-- means enter from above, but the same word on Out would exit downward, so
-- Out uses "bottom" to leave the way it came.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 6, bezier = "default", style = "slidefadevert top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 6, bezier = "default", style = "slidefadevert bottom" })

-- ─────────────────────────────────────────────────────────────────────────────
-- Environment variables (GPU selection)
-- Pin the compositor and all clients to the Intel iGPU so the RTX 5090 can
-- runtime-suspend to D3cold (~8W saved on battery). GPU-hungry apps opt back
-- in per-launch with `nvidia-offload <cmd>`. Caveat: display outputs wired to
-- the NVIDIA GPU (some HDMI/DP ports) won't work while this is set.
-- ─────────────────────────────────────────────────────────────────────────────
-- /etc/hypr-dgpu-hdmi only exists under the "dgpu-hdmi" NixOS specialisation
-- (specialisations/dgpu-hdmi.nix); when present, Hyprland also opens the
-- NVIDIA card (Intel stays the render GPU, NVIDIA only scans out) so the
-- HDMI port works — at the cost of the dGPU never suspending (~8W). Boot
-- into that specialisation from the GRUB menu to flip this; it used to be a
-- `dgpu` toggle script + ~/.config/hypr/dgpu-mode marker file, replaced
-- because a boot-time choice is what this actually needed (it can't take
-- effect without a fresh Hyprland start anyway).
-- AQ_DRM_DEVICES is colon-separated, so by-path names (which contain colons)
-- get shattered on parse — resolve them to canonical /dev/dri/cardN first.
-- Card numbering isn't stable across boots, hence resolving at startup.
local function resolve_card(path)
	local p = io.popen("readlink -f " .. path)
	local real = p:read("*l")
	p:close()
	return real
end
local intel_card = resolve_card("/dev/dri/by-path/pci-0000:00:02.0-card")
local nvidia_card = resolve_card("/dev/dri/by-path/pci-0000:02:00.0-card")
local dgpu_hdmi = io.open("/etc/hypr-dgpu-hdmi", "r")
if dgpu_hdmi then
	dgpu_hdmi:close()
	hl.env("AQ_DRM_DEVICES", intel_card .. ":" .. nvidia_card)
	-- Hardware cursors glitch on NVIDIA scanout; fall back to software
	-- rendering only in dgpu-hdmi mode.
	hl.config({ cursor = { no_hardware_cursors = true } })
else
	hl.env("AQ_DRM_DEVICES", intel_card)
end
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- ─────────────────────────────────────────────────────────────────────────────
-- Runtime state that has to survive a config reload
--
-- A reload (`hyprctl reload`, SUPER+SHIFT+C below, or a home-manager switch)
-- throws away the Lua VM entirely and re-runs this file from scratch, so
-- anything a running config put in a variable comes back nil. Two pieces of
-- state live *only* in the running compositor and used to be lost on every
-- rebuild:
--
--   * the per-workspace scrolling/hy3 toggle (`scrolling_workspaces` below),
--   * the `present` script's mirror rule (hyprland/default.nix) — which is why
--     that file warned "don't rebuild mid-presentation".
--
-- Hyprland >= 0.56 fires `config.unload` just before a reload, which is the
-- hook that lets us hand state forward. It can't go through a Lua variable
-- (fresh VM), so it goes through a file.
--
-- Reload vs. logout: `config.unload` fires on shutdown too, immediately
-- followed by `hyprland.shutdown` — so shutdown writes the file and then
-- deletes it again, and a fresh session starts clean (mirroring off, every
-- workspace back on hy3), which is the behaviour that was there before. Only a
-- reload restores. A hard crash can leave a stale file behind and cause one
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
-- the compositor is the thing that actually knows.
local function mirrored_output()
	for _, mon in ipairs(hl.get_monitors()) do
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

	-- Restate mode/position/scale for the same reason the `present` script does:
	-- a rule keyed on the output name outranks the "" wildcard above, so leaving
	-- them off would silently fall back to scale "auto".
	if saved.mirror and saved.mirror ~= "" then
		hl.monitor({
			output = saved.mirror,
			mode = "preferred",
			position = "auto",
			scale = "1",
			mirror = "eDP-1",
		})
		-- Monitor rules, unlike hl.config values, aren't re-read each frame —
		-- they need an explicit re-apply. Same two-step as `present`.
		hl.exec_cmd("hyprctl dispatch forcerendererreload")
	end
end

hl.on("config.unload", save_state)
hl.on("config.reloaded", restore_state)
-- Fires right after config.unload on exit, so a logout leaves no file behind.
hl.on("hyprland.shutdown", function()
	os.remove(state_path)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Autostart (was: exec-once)
-- Home Manager already registers a hyprland.start hook (hl.on appends, so this
-- one runs alongside it) which does `dbus-update-activation-environment
-- --systemd --all` and starts hyprland-session.target — no need to repeat any
-- env propagation or session-target handling here.
-- ─────────────────────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprctl dispatch workspace 2") -- start on the terminal workspace
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

-- -1 = single-instance: after the first window, new ones reuse the running
-- process and open in ~5ms instead of ~400ms (fonts/GPU already initialized).
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty -1"))

-- NOTE: Super+Ctrl+P used to run bash /home/dani/Projects/sai/rofi_wrapper.sh
-- ("hacky script for plotting metrics from runs"). That file no longer exists,
-- so the bind had been dead for a while; it went out with rofi. The chord is
-- free if the script comes back.

-- Lock screen when closing laptop lid. noctalia's lockscreen, not hyprlock:
-- there is only one lockscreen on this system now (see hyprland/default.nix),
-- and it is the same one noctalia's idle timers and suspend raise.
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("noctalia msg session lock"), { locked = true })

-- Utilities
hl.bind(mod .. " + D", hl.dsp.exec_cmd("vicinae toggle"))
hl.bind(
	mod .. " + SHIFT + B",
	hl.dsp.exec_cmd("bash /home/dani/nix_config/menu_launchers/scripts/choose_bluetooth_device_from_paired.sh")
)
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("bash /home/dani/nix_config/menu_launchers/scripts/open_paper.sh"))
-- Moved off SHIFT+o, which is the opacity toggle again (see below).
hl.bind(mod .. " + CONTROL + SHIFT + o", hl.dsp.exec_cmd("wl-ocr"))
-- Force the focused window fully opaque and back. Implemented as a tag rather
-- than `setprop alpha`: a tag is per-window state the compositor already tracks
-- and toggles for us, so each window remembers whether it is opaque without
-- this config having to, and the actual opacity lives in one window rule down
-- with the rest of them (opacity-opaque-tag). Global opacity is untouched.
hl.bind(mod .. " + SHIFT + o", hl.dsp.window.tag({ tag = "opaque", action = "toggle" }))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("bash /home/dani/nix_config/zsh/scripts/video/record_video.sh"))
-- Region screenshot through noctalia's annotation editor (shell.screenshot.annotate
-- in noctalia/default.nix); Enter/Done copies to the clipboard, Ctrl+S saves.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
-- Freeze the screen and draw on it in noctalia's annotation editor, then copy or save.
hl.bind(mod .. " + A", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"))
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("pavucontrol"))
-- noctalia owns clipboard history (vicinae's monitoring is off, menu_launchers/).
hl.bind(mod .. " + CONTROL + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
-- Searchable keybind cheatsheet (kenn/keybind-cheatsheet, enabled in
-- noctalia/default.nix). It reads the binds back out of the running compositor
-- over hyprctl, so it stays correct under configType = "lua" -- unlike the
-- plugins that parse hyprland.conf, which this config does not have. No bar
-- pill on purpose; this bind is the only entry point.
hl.bind(mod .. " + SHIFT + slash", hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"))
-- Alt+Tab window switcher: Tab/Shift+Tab cycle, releasing Alt commits, Escape
-- cancels. The overlay grabs the keyboard itself, so only the open is bound.
hl.bind("ALT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher"))
hl.bind(mod .. " + CONTROL + SHIFT + L", hl.dsp.exec_cmd("noctalia msg session lock"))
-- Re-read hyprland.lua in place (Hyprland >= 0.56 native dispatcher; previously
-- this was only reachable as `hyprctl reload`). Note this drops the Lua VM, so
-- runtime-only state goes through the state file — see the runtime-state
-- section near the top.
hl.bind(mod .. " + SHIFT + C", hl.dsp.reload_config())

-- Toggle bar
hl.bind(mod .. " + b", hl.dsp.exec_cmd("noctalia msg bar-toggle"))

-- Normal workspaces
hl.bind(mod .. " + Space", hl.dsp.window.float({ action = "toggle" }))

for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hy3.move_to_workspace(tostring(i), { follow = true }))
end
hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }))

-- Layout toggle: hy3 <-> Hyprland's native scrolling (niri-style) layout,
-- scoped to the active workspace via a per-workspace layout rule (Hyprland
-- >= 0.54's layout rewrite). Survives a reload now (see the runtime-state
-- section above), but still resets on relogin. The hjkl movement binds below
-- check `scrolling_workspaces` (declared up there, because config.unload has
-- to read it) to pick hy3's tree-aware dispatcher or Hyprland's native
-- direction dispatcher (which scrolling implements and hy3 doesn't).
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

	-- The toggle is otherwise silent and the two layouts look alike until you
	-- try to move a window, so say which one is live and how to get back. The
	-- synchronous hint makes a second press replace the first toast rather than
	-- stack another one (ignored by daemons that don't implement it).
	hl.exec_cmd(
		string.format(
			"notify-send -a hyprland -h string:x-canonical-private-synchronous:hypr-layout "
				.. "'Layout: %s' 'Workspace %d — %s to toggle'",
			layout,
			id,
			layout_bind
		)
	)
end)

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
	hl.bind(mod .. " + " .. key, move_focus)
	hl.bind(mod .. " + " .. dir, move_focus)
	hl.bind(mod .. " + SHIFT + " .. key, move_window)
end

hl.bind(mod .. " + SHIFT + Space", hy3.toggle_focus_layer())
hl.bind(mod .. " + C", hl.dsp.window.center())

hl.bind(mod .. " + s", hy3.set_swallow("toggle"))

hl.bind(mod .. " + t", hy3.change_group("toggletab"))
hl.bind(mod .. " + CONTROL + t", hy3.lock_tab()) -- lock a tab so it acts as a single node
hl.bind(mod .. " + g", hy3.make_group("tab"))

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())

hl.bind(mod .. " + E", hl.dsp.layout("togglesplit")) -- toggle horizontal/vertical split
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + O", hl.dsp.exec_cmd("hyprctl dispatch setprop activewindow opaque toggle"))

-- Special workspaces
hl.bind(mod .. " + Minus", hl.dsp.workspace.toggle_special())
hl.bind(mod .. " + SHIFT + Minus", hl.dsp.window.move({ workspace = "special" }))

-- Mouse
-- NOTE: the legacy `hy3:focustab, mouse` (bindn on mouse:272) is a no-op in current
-- hy3 (focus_tab requires a direction or index), so it is intentionally omitted.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Resize submap
hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
	local resize = {
		h = { x = -15, y = 0 },
		j = { x = 0, y = 15 },
		k = { x = 0, y = -15 },
		l = { x = 15, y = 0 },
	}
	for key, dir in pairs(directions) do
		local delta = { x = resize[key].x, y = resize[key].y, relative = true }
		hl.bind(key, hl.dsp.window.resize(delta), { repeating = true })
		hl.bind(dir, hl.dsp.window.resize(delta), { repeating = true })
	end
	hl.bind("escape", hl.dsp.submap("reset"))
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
end)
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
		hl.bind(key, nudge(deltas[key]), { repeating = true })
		hl.bind(dir, nudge(deltas[key]), { repeating = true })
	end
	-- ydotool wheel units are discrete clicks: REL_WHEEL +y = up.
	-- (wlrctl scroll is broken on Hyprland 0.55: axis events arrive with value120 = 0,
	-- so toolkits ignore them; ydotool injects real uinput events instead.
	-- Must be unmodified keys: holding SHIFT makes apps treat the wheel as horizontal scroll.)
	hl.bind("u", hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y 1.5"), { repeating = true })
	hl.bind("d", hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y -1.5"), { repeating = true })
	hl.bind("space", hl.dsp.exec_cmd("wlrctl pointer click left"))
	hl.bind("return", hl.dsp.exec_cmd("wlrctl pointer click left"))
	hl.bind("SHIFT + space", hl.dsp.exec_cmd("wlrctl pointer click right"))
	hl.bind("SHIFT + return", hl.dsp.exec_cmd("wlrctl pointer click right"))
	hl.bind("escape", function()
		hl.config({ cursor = { inactive_timeout = cursor_inactive_timeout } })
		hl.dispatch(hl.dsp.submap("reset"))
	end)
end)

-- wl-kbptr (vimium-style mouse control)
hl.bind(
	mod .. " + SHIFT + f",
	hl.dsp.exec_cmd(
		"wl-kbptr -o modes=floating,click -o mode_floating.source=detect --config=/home/dani/.config/wl-kbptr.yaml"
	)
)
-- Volume / Brightness
-- The nvidia driver registers a phantom `nvidia_0` backlight for its own
-- (disconnected) card0-eDP-2, and bare `brightnessctl` picks it over
-- `intel_backlight` -- which is the device actually wired to the panel
-- (card1-eDP-1, on the iGPU). Writes to nvidia_0 succeed and do nothing, so
-- the device has to be named explicitly.
local backlight = "brightnessctl -d intel_backlight"
hl.bind(mod .. " + F2", hl.dsp.exec_cmd(backlight .. " set 5%-"), { repeating = true })
hl.bind(mod .. " + SHIFT + F2", hl.dsp.exec_cmd(backlight .. " set 1%"), { repeating = true })
hl.bind(mod .. " + F3", hl.dsp.exec_cmd(backlight .. " set +5%"), { repeating = true })
hl.bind(mod .. " + SHIFT + F3", hl.dsp.exec_cmd(backlight .. " set 100%"), { repeating = true })
hl.bind(mod .. " + F6", hl.dsp.exec_cmd("pw-volume change -5%"), { repeating = true })
hl.bind(mod .. " + F7", hl.dsp.exec_cmd("pw-volume change +5%"), { repeating = true })
hl.bind(mod .. " + F5", hl.dsp.exec_cmd("pw-volume mute toggle"))
hl.bind(mod .. " + XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind(mod .. " + XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind(mod .. " + XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

-- Speech-to-text
hl.bind(mod .. " + V", hl.dsp.exec_cmd("voxtype record start"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("voxtype record stop"), { release = true })

-- Magnifier (cursor:zoom_factor; `magnify` script, was pypr's magnify plugin)
hl.bind(mod .. " + CTRL + Z", hl.dsp.exec_cmd("magnify -0.5"), { repeating = true })
hl.bind(mod .. " + SHIFT + Z", hl.dsp.exec_cmd("magnify +0.5"), { repeating = true })
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("magnify")) -- toggle zoom

-- Projector: mirror this panel onto whatever external display is attached
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("present toggle"))

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
				text_font = "FiraCode Nerd Font Mono Bold",
				text_height = 12,
				text_padding = 0,
				border_width = 1,
				-- Mirrors the tmux window pills: the selected tab is a hot coral slab
				-- with dark text, unselected tabs cool to a graphite slab with a
				-- burnt-umber rim (they used to be olive green / invisible-on-black).
				colors = {
					active = ember,
					active_border = ember,
					active_text = background,
          -- TODO
					active_alt_monitor = ember_dim,
          active_alt_monitor_border = ember_dim,
          active_alt_monitor_text = background,
          -- TODO
					urgent = color3,
					urgent_border = color3,
					urgent_text = color0,
					inactive = surface,
					inactive_border = surface,
					inactive_text = fg_dim,
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
-- Hyprtasking (plugin) — NOT loaded (not in hyprland.plugins), so its config is
-- omitted: hl.config errors on unknown keys when the plugin isn't present.
-- Re-add hyprtasking to plugins and uncomment to use it.
-- ─────────────────────────────────────────────────────────────────────────────
-- hl.config({ plugin = { hyprtasking = { layout = "grid", gap_size = 20, ... } } })

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
-- rofi dropped out of this alternation with the package itself. vicinae is a
-- layer-shell surface too and could be added here, but it animates on purpose.
hl.layer_rule({ name = "layer-no-anim", match = { namespace = "^(grim)$" }, no_anim = true })

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
	match = { class = "^(Slack|org\\.telegram\\.desktop|Element|discord)$" },
	workspace = 9,
})

-- Floating windows
hl.window_rule({ name = "float-general-title", match = { title = "^(Weather|MainPicker)$" }, float = true })
hl.window_rule({
	name = "float-general",
	match = {
		class = "^(Rofi|org\\.pulseaudio\\.pavucontrol|blueberry|mpv|imv)$",
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
hl.window_rule({ name = "tile-grayjay", match = { title = "GrayJay" }, tile = true })

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

-- "Smart gaps" / "no gaps when only" (one window or fullscreen on a workspace)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
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
	local ws = hl.get_active_workspace()
	if ws and ws.id == MESSAGING_WS and ws.windows > 0 then
		hl.exec_cmd("hyprctl dispatch hy3:changegroup tab")
	end
end

hl.on("workspace.active", tab_messaging_workspace) -- switching to ws9
hl.on("window.open", tab_messaging_workspace) -- launching an app on ws9
hl.on("window.move_to_workspace", tab_messaging_workspace) -- dragging an app onto ws9
