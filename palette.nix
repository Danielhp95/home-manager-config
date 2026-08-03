# Single source of truth for the "Ember" dark palette — warm graphite with a
# coral spark. It is deliberately kept in the same family as the
# WhiteSur-Dark-orange GTK/Qt theme (hyprland/theming.nix) so that native
# toolkit apps and apps that theme themselves (terminals, firefox, spotify,
# element, the greeter, the lock screen) read as one system.
#
# Already-existing consumers that predate this file and still carry their own
# copies of these values: kitty/kitty.conf, ghostty/default.nix,
# hyprland/hyprland.lua, menu_launchers (vicinae).
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
    # accentBright is a real lightness step above accent (7.5:1 vs 6.1:1 on
    # bg), not just a saturation push: the old ff6b4a was equiluminant with
    # accent, so the "hotter" variant vanished for red-green colour-blindness.
    accent = "e08060";
    accentBright = "ff8f66";
    accentDim = "b8654c";
    ash = "8a5a3c"; # burnt-umber ramp tail (tmux/starship flame trails); decorative only — 3:1 on bg

    # Secondary hues, shared with the terminal palette. One semantic slot
    # each, kept perceptually distinct: olive = strings/success, gold =
    # needs-attention-not-broken (ration it: at 8.4:1 it outshines accent),
    # steel = neutral metadata (paths/options/info), mauve = language
    # structure, sage = injected/dynamic values (env, interpolation),
    # error = failures only — near-equiluminant with accent (1.35:1 mutual),
    # so always pair it with a glyph or bold, never colour alone.
    olive = "8a9868";
    gold = "c8b468";
    steel = "7890a0";
    mauve = "988090";
    sage = "7aa88a";
    error = "e05252";
  };
in
colors
// {
  hash = builtins.mapAttrs (_: v: "#${v}") colors;
}
