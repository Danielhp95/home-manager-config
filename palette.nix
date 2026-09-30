# The Ember palette: warm graphite with a coral spark, in the family of the
# WhiteSur-Dark-orange GTK/Qt theme (hyprland/theming.nix).
#
# Hand-kept copies, for files that can't import this one: hyprland.lua (read
# verbatim), kitty/shaders/ember-blaze.pipeline (linear RGB) and danvim's
# palette.lua (a standalone flake; same attribute names).
#
# Attributes are bare hex; `hash` is the same set with '#', `ansi` the
# terminal palette, `light` the light-mode set under the same names.
let
  colors = {
    # Surfaces, darkest to lightest.
    bgDeep = "141312"; # sidebars, sunken areas
    bg = "1c1b19"; # default background
    bgAlt = "242320"; # cards, status bars, secondary surfaces
    surface = "2a2825"; # hovered/selected rows
    border = "3a342d";
    divider = "4c4b49"; # thin separators drawn on top of surface (tmux dividers)

    # Text.
    fg = "d8d0c0";
    fgSoft = "b8b0a0"; # secondary text one step above fgDim (branch names, window titles)
    fgDim = "9a9288";
    muted = "6e6a66"; # disabled text, bright-black

    # Accent: the coral that stands in for WhiteSur's orange. accentBright is a
    # lightness step (7.5:1 vs 6.1:1 on bg), so it stays distinct to red-green
    # colour-blind eyes.
    accent = "e08060";
    accentBright = "ff8f66";
    accentDim = "b8654c";
    ash = "8a5a3c"; # burnt-umber ramp tail (tmux/starship flame trails); decorative only — 3:1 on bg

    # One semantic slot each: olive = strings/success; gold = emphasis (paths,
    # folders, workspaces, warnings; ration it, it outshines accent); steel =
    # quiet metadata (flags, version pills, inlay hints, ANSI blue); mauve =
    # language structure; sage = injected/dynamic values; error = failures only.
    # "steel" now holds magma orange; the name stays because every consumer
    # uses it. error and steel are near-equiluminant with accent: never
    # contrast them against coral by hue alone.
    olive = "8a9868";
    gold = "c8b468";
    steel = "ef7f38";
    mauve = "988090";
    sage = "7aa88a";
    error = "e05252";

    # Bright ANSI companions (color9-14): same hues, lighter. Terminal-only.
    oliveBright = "acc66d";
    goldBright = "e3cc75";
    steelBright = "fb9c5f";
    mauveBright = "c586b0";
    sageBright = "84d19f";
  };

  # ── Ember Light ──────────────────────────────────────────────────────────
  # Warm paper, slot for slot with the same *semantics* rather than lightness:
  # bgDeep is still the sunken surface (darker than bg), accentBright still
  # the higher-contrast accent (reached by going darker). Used by noctalia and
  # vicinae; no terminal uses it, so its ANSI tail is untested.
  lightColors = {
    # Surfaces: bgDeep is the sunken end, divider the most prominent.
    bgDeep = "eae2d4";
    bg = "f5efe4";
    bgAlt = "ece5d8";
    surface = "e0d8c8";
    border = "cfc4b0";
    divider = "b8ac96";

    # Text.
    fg = "2a2620"; # 13.1:1
    fgSoft = "4a443c"; # 8.4:1
    fgDim = "6b6459"; # 5.1:1
    muted = "8a8274"; # 3.3:1 — disabled text only

    # Accent. Same rationing rule as the dark palette.
    accent = "ad4d33"; # 4.7:1
    accentBright = "8f3820"; # 6.7:1
    accentDim = "cf8368"; # 2.6:1 — fills and decoration, never text
    ash = "9c6644"; # 4.2:1 — burnt-umber ramp tail, decorative

    # Secondary hues, same semantic slots as above.
    olive = "5a6b38";
    gold = "826819"; # 4.7:1 — no longer outshines accent the way it does on dark
    steel = "a84e16"; # 4.9:1 — light-mode magma, same burnt-orange hue as dark
    mauve = "6b4a5a";
    sage = "3f6b52";
    error = "b3261e"; # 1.2:1 against accent — pair with a glyph, never colour alone

    # Bright ANSI companions: on light, "bright" means darker (more prominent).
    oliveBright = "44541f";
    goldBright = "6a5306";
    steelBright = "8a3f10";
    mauveBright = "553646";
    sageBright = "27553c";
  };

  # ANSI 0-15 (kitty, ghostty, the Linux console): black red green yellow blue
  # magenta cyan white, then the bright row. Dark palette only.
  ansi = [
    colors.bg
    colors.accent
    colors.olive
    colors.gold
    colors.steel
    colors.mauve
    colors.sage
    colors.fg
    colors.muted
    colors.accentBright
    colors.oliveBright
    colors.goldBright
    colors.steelBright
    colors.mauveBright
    colors.sageBright
    "ffffff"
  ];

  hex = v: if builtins.isList v then map (x: "#${x}") v else "#${v}";
  withHash = c: c // { hash = builtins.mapAttrs (_: hex) c; };
in
withHash (colors // { inherit ansi; }) // { light = withHash lightColors; }
