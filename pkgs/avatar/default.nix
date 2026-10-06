# The avatar (~/.face and the greeter's AccountsService icon) on the palette's
# `surface`. ratchet.png was drawn on Ember's surface, #2a2825.
{ pkgs, theme }:
pkgs.callPackage ./recolour.nix { inherit theme; } {
  src = ./ratchet.png;
  from = "2a2825";
  to = theme.surface;
}
