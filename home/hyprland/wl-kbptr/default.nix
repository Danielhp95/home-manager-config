# wl-kbptr: vimium-style mouse control, bound in ../hyprland.lua. The package
# (./package.nix) is pkgs.wl-kbptr through the overlay.
{
  lib,
  pkgs,
  theme,
  ...
}:
let
  h = theme.hash;
in
{
  home.packages = [ pkgs.wl-kbptr ];

  # wl-kbptr's default config path (INI). Unset keys take wl-kbptr's defaults.
  xdg.configFile."wl-kbptr/config".text = lib.generators.toINI { } {
    general.modes = "floating,click";

    mode_tile = {
      label_color = h.fg;
      label_select_color = h.gold;
      unselectable_bg_color = "${h.bgDeep}66";
      selectable_bg_color = h.ash;
      selectable_border_color = h.fgDim;
    };

    # Vimium's link hints (../../firefox/vimium-hints.nix): accent letters on
    # a deep tag, white for the characters already typed. The size is fixed:
    # min and max agree, so the percentage of the target's height is moot.
    mode_floating = {
      source = "detect";
      label_color = h.accent;
      label_select_color = h.term.brightWhite;
      unselectable_bg_color = "${h.bgDeep}66";
      selectable_bg_color = h.bgDeep;
      selectable_border_color = "${h.accent}59";
      label_font_family = theme.fonts.ui;
      label_font_size = "13.8 1% 13.8";
    };

    mode_bisect = {
      label_color = h.fg;
      pointer_color = h.accent;
      unselectable_bg_color = h.bgDeep;
      even_area_bg_color = h.ash;
      even_area_border_color = h.fgDim;
      odd_area_bg_color = h.muted;
      odd_area_border_color = h.fgSoft;
      history_border_color = h.gold;
    };

    mode_split = {
      pointer_color = h.accent;
      bg_color = h.bgDeep;
      area_bg_color = h.ash;
      vertical_color = h.muted;
      horizontal_color = h.fgDim;
      history_border_color = h.gold;
    };

    mode_click.button = "left";

    mode_drag = {
      start_marker_color = h.gold;
      start_marker_size = 10;
      start_marker_shape = "caret";
    };
  };
}
