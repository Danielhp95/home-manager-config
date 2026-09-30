{ lib, ... }:

let
  p = (import ../palette.nix).hash;
in
{
  programs.kitty = {
    enable = true;
    font.name = (import ../fonts.nix).mono;
    # Ember colours from ../palette.nix. kitty.conf is written after these and
    # would override them, so it must not set any.
    settings = {
      background = p.bg;
      foreground = p.fg;
      selection_background = p.border;
      selection_foreground = p.fg;
      cursor = p.accent;
      cursor_text_color = p.bg;
      url_color = p.steel;
      # Magma (steel), the quiet-metadata slot.
      active_border_color = p.steel;
      # Gold, not coral: coral is equiluminant with the magma active border, so
      # a coral bell wouldn't show. Gold is the system-wide attention colour.
      bell_border_color = p.gold;
    }
    // lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair "color${toString i}" c) p.ansi);
    extraConfig = builtins.readFile ./kitty.conf;
  };

  # Pipelines for `custom_shaders` in kitty.conf.
  xdg.configFile."kitty/shaders".source = ./shaders;
}
