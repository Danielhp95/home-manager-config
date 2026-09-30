{ lib, ... }:

let
  p = (import ../palette.nix).hash;
in
{
  programs.kitty = {
    enable = true;
    font.name = (import ../fonts.nix).mono;
    # The Ember colours, from ../palette.nix. HM writes these ahead of
    # kitty.conf, which no longer sets any of them.
    settings = {
      background = p.bg;
      foreground = p.fg;
      selection_background = p.border;
      selection_foreground = p.fg;
      cursor = p.accent;
      cursor_text_color = p.bg;
      url_color = p.steel;
      # Magma (palette.nix steel): the quiet-metadata slot, same as the old blue.
      active_border_color = p.steel;
      # Gold, not coral: magma active borders are equiluminant with coral
      # (1.05:1), so a coral bell would be invisible next to them. Gold is the
      # system-wide attention color (hy3 urgent tabs, tmux copy badge).
      bell_border_color = p.gold;
    }
    // lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair "color${toString i}" c) p.ansi);
    extraConfig = builtins.readFile ./kitty.conf;
  };

  # Pipelines for `custom_shaders` in kitty.conf.
  xdg.configFile."kitty/shaders".source = ./shaders;
}
