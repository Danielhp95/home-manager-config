# The one value every themed module takes as an argument (`theme`, passed
# through specialArgs in flake.nix): the selected palette with the fonts and
# the colour helpers beside it, so a consumer needs one binding and no
# relative import.
#
#   theme.<slot>, theme.hash, theme.slots, theme.ansi, theme.light, theme.meta …
#                   the built palette, as palette/lib.nix documents it
#   theme.fonts     ./fonts.nix
#   theme.colour    ./lib/colour.nix: every colour format and all colour arithmetic
#
# It composes and selects nothing: which palette is the one line in
# ./palette/default.nix. The argument exists so that a check can evaluate the
# whole configuration under a palette that is not the selected one.
{
  lib,
  palette ? import ./palette,
}:
palette
// {
  fonts = import ./fonts.nix;
  colour = import ./lib/colour.nix { inherit lib; };
}
