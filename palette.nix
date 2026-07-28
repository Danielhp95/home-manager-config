# Single source of truth for the "Ember" dark palette — warm graphite with a
# coral spark. It is deliberately kept in the same family as the
# WhiteSur-Dark-orange GTK/Qt theme (hyprland/theming.nix) so that native
# toolkit apps and apps that theme themselves (terminals, firefox, spotify,
# element, the greeter, the lock screen) read as one system.
#
# Already-existing consumers that predate this file and still carry their own
# copies of these values: kitty/kitty.conf, ghostty/default.nix,
# hyprland/hyprland.lua, terminal/television.nix, menu_launchers (vicinae).
#
# Attributes are bare hex (no leading '#'); `hash` holds the same set prefixed
# with '#' for config formats that require it.
let
  colors = {
    # Surfaces, darkest to lightest.
    bgDeep = "141312"; # sidebars, sunken areas
    bg = "1c1b19"; # default background
    bgAlt = "242320"; # cards, status bars, secondary surfaces
    surface = "2a2825"; # hovered/selected rows
    border = "3a342d";

    # Text.
    fg = "d8d0c0";
    fgDim = "9a9288";
    muted = "6e6a66"; # disabled text, bright-black

    # Accent — the coral that stands in for WhiteSur's orange.
    accent = "e08060";
    accentBright = "ff6b4a";
    accentDim = "b8654c";

    # Secondary hues, shared with the terminal palette.
    olive = "8a9868";
    gold = "c8b468";
    steel = "7890a0";
    mauve = "988090";
    sage = "80a090";
    error = "e05252";
  };
in
colors
// {
  hash = builtins.mapAttrs (_: v: "#${v}") colors;
}
