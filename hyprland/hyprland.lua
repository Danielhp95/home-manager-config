-- Welcome to my hyprland.lua!
--
-- Lua-equivalent of hyprland.conf (Hyprland >= 0.55, hy3 with lua support).
-- Home Manager prepends `hl.plugin.load(<hy3>)` and a `hl.on("hyprland.start", ...)`
-- systemd-activation hook before this file, so hl.plugin.hy3.* and the hy3 config
-- values are available below.
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
local color3 = "rgb(c8b468)" -- yellow / gold
local color4 = "rgb(7890a0)" -- blue   / steel
local color5 = "rgb(988090)" -- magenta/ mauve
local color6 = "rgb(80a090)" -- cyan   / sage
local color7 = "rgb(d8d0c0)" -- white  / fg0

-- ─────────────────────────────────────────────────────────────────────────────
-- Monitors
-- ─────────────────────────────────────────────────────────────────────────────
-- monitor =,preferred,auto,1
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- General / Misc / Input / Cursor / Decoration / Animations / Binds / dwindle
-- ─────────────────────────────────────────────────────────────────────────────
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
			active_border = { colors = { color1, color3, color1 }, angle = 90 },
			inactive_border = color6,
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
		inactive_timeout = 5,
		no_hardware_cursors = true,
	},

	decoration = {
		active_opacity = 0.90,
		inactive_opacity = 0.8,
		fullscreen_opacity = 1.0,
		rounding = 5,
		blur = {
			enabled = true,
			size = 8,
			passes = 4,
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
})

-- Animations: curves + per-leaf settings
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "default", style = "slidefadevert" })

-- ─────────────────────────────────────────────────────────────────────────────
-- Environment variables (GPU selection)
-- Pin the compositor and all clients to the Intel iGPU so the RTX 5090 can
-- runtime-suspend to D3cold (~8W saved on battery). GPU-hungry apps opt back
-- in per-launch with `nvidia-offload <cmd>`. Caveat: display outputs wired to
-- the NVIDIA GPU (some HDMI/DP ports) won't work while this is set.
-- ─────────────────────────────────────────────────────────────────────────────
-- The `dgpu` command toggles a marker file; when present, Hyprland also opens
-- the NVIDIA card (Intel stays the render GPU, NVIDIA only scans out) so the
-- HDMI port works — at the cost of the dGPU never suspending (~8W). Takes
-- effect on the next Hyprland start (log out/in after toggling).
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
local dgpu_marker = io.open(os.getenv("HOME") .. "/.config/hypr/dgpu-mode", "r")
if dgpu_marker then
	dgpu_marker:close()
	hl.env("AQ_DRM_DEVICES", intel_card .. ":" .. nvidia_card)
else
	hl.env("AQ_DRM_DEVICES", intel_card)
end
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- ─────────────────────────────────────────────────────────────────────────────
-- Autostart (was: exec-once)
-- Home Manager already registers a hyprland.start hook for systemd activation;
-- hl.on appends, so this one runs alongside it.
-- ─────────────────────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
	-- propagate the wayland environment to the dbus/session daemons
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME"
	)

	hl.exec_cmd("fcitx5")
	hl.exec_cmd("pypr")
	hl.exec_cmd("hyprctl dispatch workspace 2") -- start on the terminal workspace
	-- noctalia is started via its systemd user service (see noctalia/default.nix)
	hl.exec_cmd("vicinae server") -- launcher
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

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))

-- Hacky script for plotting metrics from runs
hl.bind(mod .. " + CTRL + p", hl.dsp.exec_cmd("bash /home/dani/Projects/sai/rofi_wrapper.sh"))

-- Lock screen when closing laptop lid
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprlock --immediate"), { locked = true })

-- Utilities
hl.bind(mod .. " + D", hl.dsp.exec_cmd("vicinae toggle"))
hl.bind(
	mod .. " + SHIFT + B",
	hl.dsp.exec_cmd("bash /home/dani/nix_config/menu_launchers/scripts/choose_bluetooth_device_from_paired.sh")
)
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("bash /home/dani/nix_config/menu_launchers/scripts/open_paper.sh"))
hl.bind(mod .. " + SHIFT + o", hl.dsp.exec_cmd("wl-ocr"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("bash /home/dani/nix_config/zsh/scripts/video/record_video.sh"))
hl.bind(
	mod .. " + SHIFT + S",
	hl.dsp.exec_cmd("hyprshot --mode=region --raw --clipboard-only | satty -f - --copy-command wl-copy --early-exit")
)
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("pavucontrol"))
hl.bind(mod .. " + CONTROL + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

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

-- Focus / move window (hy3), vim keys and arrows
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(directions) do
	hl.bind(mod .. " + " .. key, hy3.move_focus(dir))
	hl.bind(mod .. " + " .. dir, hy3.move_focus(dir))
	hl.bind(mod .. " + SHIFT + " .. key, hy3.move_window(dir))
end

hl.bind(mod .. " + SHIFT + Space", hy3.toggle_focus_layer())
hl.bind(mod .. " + C", hl.dsp.window.center())

hl.bind(mod .. " + s", hy3.set_swallow("toggle"))

hl.bind(mod .. " + t", hy3.change_group("toggletab"))
hl.bind(mod .. " + CONTROL + t", hy3.lock_tab()) -- lock a tab so it acts as a single node
hl.bind(mod .. " + g", hy3.make_group("tab"))

hl.bind(mod .. " + SHIFT + Q", hy3.kill_active())

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

-- Mouse-cursor submap: vim-style hjkl pointer movement via wlrctl, escape to leave
-- u / d scroll the wheel up / down
hl.bind(mod .. " + M", hl.dsp.submap("move"))
hl.define_submap("move", function()
	local deltas = {
		h = "-25 0",
		j = "0 25",
		k = "0 -25",
		l = "25 0",
	}
	for key, dir in pairs(directions) do
		hl.bind(key, hl.dsp.exec_cmd("wlrctl pointer move " .. deltas[key]), { repeating = true })
		hl.bind(dir, hl.dsp.exec_cmd("wlrctl pointer move " .. deltas[key]), { repeating = true })
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
	hl.bind("escape", hl.dsp.submap("reset"))
end)

-- wl-kbptr (vimium-style mouse control)
hl.bind(
	mod .. " + SHIFT + f",
	hl.dsp.exec_cmd(
		"wl-kbptr -o modes=floating,click -o mode_floating.source=detect --config=/home/dani/.config/wl-kbptr.yaml"
	)
)
-- Volume / Brightness
hl.bind(mod .. " + F2", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })
hl.bind(mod .. " + SHIFT + F2", hl.dsp.exec_cmd("brightnessctl set 0%"), { repeating = true })
hl.bind(mod .. " + F3", hl.dsp.exec_cmd("brightnessctl set +5%"), { repeating = true })
hl.bind(mod .. " + SHIFT + F3", hl.dsp.exec_cmd("brightnessctl set 100%"), { repeating = true })
hl.bind(mod .. " + F6", hl.dsp.exec_cmd("pw-volume change -5%"), { repeating = true })
hl.bind(mod .. " + F7", hl.dsp.exec_cmd("pw-volume change +5%"), { repeating = true })
hl.bind(mod .. " + F5", hl.dsp.exec_cmd("pw-volume mute toggle"))
hl.bind(mod .. " + XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind(mod .. " + XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind(mod .. " + XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

-- Speech-to-text
hl.bind(mod .. " + V", hl.dsp.exec_cmd("voxtype record start"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("voxtype record stop"), { release = true })

-- Pypr (magnify plugin)
hl.bind(mod .. " + CTRL + Z", hl.dsp.exec_cmd("pypr zoom --0.5"))
hl.bind(mod .. " + SHIFT + Z", hl.dsp.exec_cmd("pypr zoom ++0.5"))
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("pypr zoom")) -- toggle zoom

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
				colors = {
					active = color2,
					active_border = color2,
					active_text = background,
					urgent = color3,
					urgent_border = color3,
					urgent_text = "rgb(000000)",
					inactive = background,
					inactive_border = background,
					inactive_text = foreground,
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
hl.layer_rule({ name = "layer-no-anim", match = { namespace = "^(rofi|grim|hyprshot)$" }, no_anim = true })

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
	match = { class = "^(Slack|org\\.telegram\\.desktop|Element)$" },
	workspace = 9,
})

-- Floating windows
hl.window_rule({ name = "float-general-title", match = { title = "^(Weather|MainPicker)$" }, float = true })
hl.window_rule({
	name = "float-general",
	match = {
		class = "^(io\\.github\\.amit9838\\.mousam|Rofi|org\\.pulseaudio\\.pavucontrol|blueberry|mpv|imv|satty)$",
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
	match = { class = "^(org\\.pulseaudio\\.pavucontrol|zoom|firefox|satty|mpv|matplotlib)$" },
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
