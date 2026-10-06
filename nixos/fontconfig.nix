# System fonts and fontconfig defaults, from ../fonts.nix.
{ pkgs, theme, ... }:
let
  f = theme.fonts;
in
{
  fonts = {
    packages = f.packages pkgs;
    fontconfig.defaultFonts = {
      sansSerif = [ f.ui ] ++ f.cjkSans ++ [ f.emoji ];
      serif = f.serif ++ [ f.emoji ];
      # No emoji here: kitty asks `monospace` for text-presentation symbols
      # the main font lacks (✔ ❤ ⏱) and crops the colour bitmap to a corner
      # of the cell. Real emoji come through the `emoji` family regardless.
      monospace = [ f.mono ];
      emoji = [ f.emoji ];
    };
  };
}
