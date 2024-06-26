-- Generated by Home Manager.
-- See https://wezfurlong.org/wezterm/

local wezterm = require 'wezterm';

-- Generated by Home Manager.
-- See https://wezfurlong.org/wezterm/

local wezterm = require 'wezterm';

local wezterm = require 'wezterm'
local act = wezterm.action

local home = os.getenv("HOME")

wezterm.add_to_config_reload_watch_list(home .. '~/.cache/wal/colors')



local xcursor_size = nil
local xcursor_theme = nil

return {
  mouse_bindings = {
    {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'CTRL',
      action = act.IncreaseFontSize,
    },
    {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'CTRL',
      action = act.DecreaseFontSize,
    },
  },
  adjust_window_size_when_changing_font_size = false,
  window_decorations = "NONE",
  initial_rows = 50,
  initial_cols = 140,
  enable_tab_bar = false,
  switch_to_last_active_tab_when_closing_tab = true,
  enable_scroll_bar = false,
  underline_position = -1,
  cursor_thickness = 1,
  max_fps = 165,
  window_close_confirmation = 'NeverPrompt',
  window_padding = {
    right = 0,
    left = 0,
    top = 0,
    bottom = 0,
  },
  font = wezterm.font 'FiraCode Nerd Font Mono',
  font_size = 12.0,
  line_height = 1.,
  -- color_scheme_dirs = { home .. '/.cache/wal' },
  -- color_scheme = "Pywal",
  text_background_opacity = 1.0,
  window_background_opacity = .65,

  -- Cursor
  hide_mouse_cursor_when_typing = false;
}


