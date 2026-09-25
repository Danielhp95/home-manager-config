# System fonts and fontconfig defaults, from ../fonts.nix.
{ pkgs, ... }:
let
  f = import ../fonts.nix;
in
{
  fonts = {
    packages = f.packages pkgs;
    fontconfig.defaultFonts = {
      sansSerif = [ f.ui ] ++ f.cjkSans ++ [ f.emoji ];
      serif = f.serif ++ [ f.emoji ];
      monospace = [
        f.mono
        f.emoji
      ];
      emoji = [ f.emoji ];
    };
  };
}
