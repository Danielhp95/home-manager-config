{ ... }:

# Ghostty configuration — a faithful equivalent of kitty/kitty.conf.
# Validated against ghostty 1.3.1 with `ghostty +validate-config`.
#
# NOTE ON HINTS (kitty's `hints` kitten): ghostty has NO native hints / keyboard
# URL-open feature (tracked upstream in ghostty-org/ghostty#2012 and #2394, still
# open). Our kitty `ctrl+shift+p>u/f/l/w` hints are ALREADY replicated, terminal-
# agnostically, by tmux-thumbs in tmux/default.nix: `prefix+p` enters the `hints`
# key-table, then u/U (url), f/F (path), l/L (line), w/W (word) copy/paste. That
# works identically under ghostty, so switching terminals does not lose hints —
# as long as you are inside tmux.
#
# NOTE ON ICONS: unlike kitty, ghostty bundles a Nerd Font fallback, so kitty's
# `symbol_map` blocks are unnecessary here and intentionally omitted.

{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # ── Fonts ──────────────────────────────────────────────────────────────
      font-family = "JetBrainsMono Nerd Font Mono";
      # kitty `adjust_line_height 117%`; ghostty adds on top of base → 17% = 117%.
      adjust-cell-height = "17%";

      # ── Colors: EMBER theme (ported from kitty.conf) ────────────────────────
      background = "#1c1b19";
      foreground = "#d8d0c0";
      selection-background = "#3c3b39";
      selection-foreground = "#d8d0c0";
      cursor-color = "#e08060";
      cursor-text = "#1c1b19";
      # 16 ANSI colors (kitty color0–color15). ghostty `palette = N=#hex`.
      palette = [
        "0=#1c1b19" # black
        "8=#6e6a66"
        "1=#e08060" # red (coral)
        "9=#ff6b4a"
        "2=#8a9868" # green (olive)
        "10=#b8d8a3"
        "3=#c8b468" # yellow (gold)
        "11=#e5c07b"
        "4=#7890a0" # blue (steel)
        "12=#8ab4f8"
        "5=#988090" # magenta (mauve)
        "13=#d19a66"
        "6=#80a090" # cyan (sage)
        "14=#7fbbb3"
        "7=#d8d0c0" # white
        "15=#ffffff"
      ];

      # ── Cursor ──────────────────────────────────────────────────────────────
      cursor-style = "block";
      cursor-style-blink = true;
      # kitty `shell_integration enabled no-cursor`.
      shell-integration-features = "no-cursor";

      # ── Scrollback / mouse ──────────────────────────────────────────────────
      scrollback-limit = 2000; # mirrors kitty `scrollback_lines 2000`
      mouse-scroll-multiplier = 5; # kitty `wheel_scroll_multiplier 5.0`
      copy-on-select = false;
      focus-follows-mouse = false;
      mouse-hide-while-typing = true; # closest to kitty `mouse_hide_wait 3.0`

      # ── Window ────────────────────────────────────────────────────────────────
      background-opacity = 0.87;
      window-save-state = "always"; # kitty `remember_window_size yes`
      window-padding-x = 0;
      window-padding-y = 0;

      # ── macOS (harmless on Linux) ──────────────────────────────────────────
      macos-option-as-alt = true;

      # ── Keybindings (kitty_mod = ctrl+shift) ─────────────────────────────────
      keybind = [
        # Clipboard
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+s=paste_from_selection"
        "shift+insert=paste_from_selection"

        # Scrolling. NOTE: ctrl+shift+j / ctrl+shift+k are intentionally NOT bound
        # so ghostty forwards them to the running program — Neovim's floaterm uses
        # them to cycle terminal buffers. This mirrors the unmap in kitty.conf.
        "ctrl+shift+up=scroll_page_lines:-1"
        "ctrl+shift+down=scroll_page_lines:1"
        "ctrl+shift+page_up=scroll_page_up"
        "ctrl+shift+page_down=scroll_page_down"
        "ctrl+shift+home=scroll_to_top"
        "ctrl+shift+end=scroll_to_bottom"

        # Window / split management
        # kitty `new_window` → split pane; kitty `new_os_window` → new OS window.
        "ctrl+shift+enter=new_split:right"
        "ctrl+shift+n=new_window"
        "ctrl+shift+w=close_surface"
        "ctrl+shift+]=goto_split:next"
        "ctrl+shift+[=goto_split:previous"

        # Jump to tab by index (kitty first_window … ninth_window)
        "ctrl+shift+1=goto_tab:1"
        "ctrl+shift+2=goto_tab:2"
        "ctrl+shift+3=goto_tab:3"
        "ctrl+shift+4=goto_tab:4"
        "ctrl+shift+5=goto_tab:5"
        "ctrl+shift+6=goto_tab:6"
        "ctrl+shift+7=goto_tab:7"
        "ctrl+shift+8=goto_tab:8"
        "ctrl+shift+9=goto_tab:9"

        # Tab management
        "ctrl+shift+right=next_tab"
        "ctrl+shift+left=previous_tab"
        "ctrl+shift+t=new_tab"
        "ctrl+shift+q=close_tab"
        "ctrl+shift+alt+t=toggle_tab_overview"

        # Font sizes
        "ctrl+shift+equal=increase_font_size:2"
        "ctrl+shift+minus=decrease_font_size:2"
        "ctrl+shift+backspace=reset_font_size"

        # Misc. ghostty only supports TOGGLING opacity (no incremental step like
        # kitty's set_background_opacity +0.1), so the a>m/a>l binds don't port.
        "ctrl+shift+a>t=toggle_background_opacity"
        "ctrl+shift+f11=toggle_fullscreen"
        "ctrl+shift+delete=clear_screen"
      ];
    };
  };
}
