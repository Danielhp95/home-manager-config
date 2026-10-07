{
  lib,
  pkgs,
  theme,
  ...
}:

let
  palette = theme;
  p = palette.hash;

  # The cursor trail in two palette slots, chosen per palette (meta.trail).
  slot = name: {
    slot = name;
    hex = palette.${name};
  };
  trail = pkgs.callPackage ./trail.nix { inherit theme; } {
    fill = slot palette.meta.trail.fill;
    rim = slot palette.meta.trail.rim;
  };

  hintTypes = {
    u = "url";
    f = "path";
    l = "line";
    w = "word";
  };

  # Every Nerd Font icon from the symbols font: kitty has no bundled icon
  # fallback, so glyphs the text font lacks would render as tofu.
  nerdRanges = [
    "U+23FB-U+23FE,U+2665,U+26A1,U+2B58"
    "U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D7"
    "U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6B7"
    "U+E700-U+E8EF,U+EA60-U+EC1E,U+ED00-U+EFCE"
    "U+F000-U+F2FF,U+F300-U+F381,U+F400-U+F533"
    "U+F0001-U+F1AF0"
  ];
  symbolMaps =
    lib.concatMapStrings (range: "symbol_map ${range} ${theme.fonts.symbols}\n") nerdRanges
    # Media-control symbols (the play and pause shapes, Claude Code's mode
    # indicators) aren't Nerd Font glyphs: Noto Sans Symbols 2 covers them
    # except U+23EB/U+23EC (Unifont). U+23F0-U+23F3 are left to fontconfig:
    # the alarm clock and hourglass are emoji, the stopwatch and timer fall
    # back to a text font. Check with: fc-list ':charset=23F8' family
    + ''
      symbol_map U+23E9-U+23EA,U+23ED-U+23EF,U+23F4-U+23FA Noto Sans Symbols 2
      symbol_map U+23EB-U+23EC Unifont
    ''
    # U+2702 (scissors): in neither Nerd Font, and the fontconfig fallback drew
    # it blank.
    + "symbol_map U+2702 Noto Sans Symbols 2\n";
in
{
  programs.kitty = {
    enable = true;
    font.name = theme.fonts.mono;
    # Only what differs from kitty's defaults: `kitty +runpy` with
    # kitty.config.load_config shows the effective value of every option.
    settings = {
      # ── Colours, from the palette ──
      background = p.bg;
      foreground = p.fg;
      selection_background = p.border;
      selection_foreground = p.fg;
      cursor = p.accent;
      cursor_text_color = p.bg;
      url_color = p.steel;
      # steel, the quiet-metadata slot.
      active_border_color = p.steel;
      # Unfocused splits recede, as tmux's pane borders do.
      inactive_border_color = p.border;
      # Gold, the system-wide attention colour.
      bell_border_color = p.gold;

      # Tabs as the tmux window pills and the hy3 tabs: the selected one an
      # accent slab with dark text, the rest graphite.
      active_tab_foreground = p.bg;
      active_tab_background = p.accent;
      inactive_tab_foreground = p.fgSoft;
      inactive_tab_background = p.surface;

      # An absolute store path, not a name: kitty caches pipelines by name and
      # recompiles on reload only when this option's value changes.
      custom_shaders = "${trail}/cursor-trail.pipeline";

      # ── Cursor ──
      # Rest time before the trail follows; raising it makes typing bursts trail.
      cursor_trail = 4;
      cursor_trail_decay = "0.5 0.1";
      # Trail only on jumps over 40 columns or 5 rows, not while typing.
      cursor_trail_start_threshold = "40 5";
      # The shell's own cursor shape stays (zsh's vi-mode cursor).
      shell_integration = "enabled no-cursor";
      cursor_blink_interval = "0.5";

      # ── Text ──
      modify_font = "cell_height 117%";
      select_by_word_characters = ":@-./_~?&=%+#";

      # Off: under tmux a redraw arrives as one burst, and a burst that just
      # misses a vblank waits a whole frame (16.7ms at 60Hz) on a ~29ms Enter
      # round trip. The cost is tearing while scrolling; set it back to true if
      # that shows.
      sync_to_monitor = false;

      # ── Bell ──
      enable_audio_bell = false;
      window_alert_on_bell = false;
      bell_on_tab = "no";

      # ── Window ──
      window_border_width = "1.0";
      # Horizontal padding: the prompt's round pill caps need air from the edge.
      window_padding_width = "0 8";
      tab_title_template = "{title}";
      background_opacity = "0.87";
      dynamic_background_opacity = true;
      dim_opacity = "1.0";

      clipboard_control = "write-clipboard write-primary";
    }
    // lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair "color${toString i}" c) p.ansi);

    # Only the bindings that are not kitty's own (kitty_mod is ctrl+shift).
    keybindings = {
      # kitty's default for these two is now `scroll_line_up smooth`.
      "kitty_mod+up" = "scroll_line_up";
      "kitty_mod+down" = "scroll_line_down";
      # Unmapped (empty action) so they reach the program: Neovim's floaterm
      # uses them.
      "kitty_mod+k" = "";
      "kitty_mod+j" = "";
    }
    # Hints: p>u/f/l/w copies a url/path/line/word; with shift, pastes it.
    // lib.concatMapAttrs (key: type: {
      "kitty_mod+p>${key}" = "kitten hints --type ${type} --program @";
      "kitty_mod+p>shift+${key}" = "kitten hints --type ${type} --program -";
    }) hintTypes;

    extraConfig = symbolMaps;
  };
}
