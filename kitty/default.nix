{ lib, pkgs, ... }:

let
  palette = import ../palette.nix;
  p = palette.hash;

  # The cursor trail in two palette slots, chosen per palette (meta.trail).
  slot = name: {
    slot = name;
    hex = palette.${name};
  };
  trail = pkgs.callPackage ./trail.nix { } {
    fill = slot palette.meta.trail.fill;
    rim = slot palette.meta.trail.rim;
  };
in
{
  programs.kitty = {
    enable = true;
    font.name = (import ../fonts.nix).mono;
    # Colours from ../palette.nix. kitty.conf is written after these and would
    # override them, so it must not set any of these.
    settings = {
      background = p.bg;
      foreground = p.fg;
      selection_background = p.border;
      selection_foreground = p.fg;
      cursor = p.accent;
      cursor_text_color = p.bg;
      url_color = p.steel;
      # steel, the quiet-metadata slot.
      active_border_color = p.steel;
      # Gold, the system-wide attention colour.
      bell_border_color = p.gold;

      # An absolute store path, not a name: kitty caches pipelines by name and
      # recompiles on reload only when this option's value changes.
      custom_shaders = "${trail}/cursor-trail.pipeline";
    }
    // lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair "color${toString i}" c) p.ansi);
    extraConfig = builtins.readFile ./kitty.conf;
  };
}
