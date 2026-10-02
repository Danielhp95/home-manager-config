{ lib, ... }:

# Ghostty, set up to match kitty/kitty.conf. It has no hints kitten
# (ghostty-org/ghostty#2012, #2394); tmux-thumbs (prefix+p) covers that inside
# tmux. Its bundled Nerd Font fallback makes kitty's symbol_map unnecessary.

let
  p = (import ../palette).hash;
in
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # ── Fonts ──────────────────────────────────────────────────────────────
      font-family = (import ../fonts.nix).mono;
      # kitty's adjust_line_height 117%: ghostty takes the increase.
      adjust-cell-height = "17%";

      # ── Colors: Ember, from ../palette/ ─────────────────────────────────
      background = p.bg;
      foreground = p.fg;
      selection-background = p.border;
      selection-foreground = p.fg;
      cursor-color = p.accent;
      cursor-text = p.bg;
      # ANSI 0-15, as `N=#hex`.
      palette = lib.imap0 (i: c: "${toString i}=${c}") p.ansi;

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
      # Nonzero x: the prompt's round pill caps need air from the window edge.
      window-padding-x = 10;
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

        # Scrolling. ctrl+shift+j/k stay unbound: Neovim's floaterm uses them
        # (kitty.conf unmaps them too).
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

        # Misc. Opacity can only be toggled, so kitty's a>m/a>l steps don't port.
        "ctrl+shift+a>t=toggle_background_opacity"
        "ctrl+shift+f11=toggle_fullscreen"
        "ctrl+shift+delete=clear_screen"
      ];
    };
  };
}
