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
# danvim/lua/danvim/palette.lua is a hand-kept mirror by necessity rather than
# by history: danvim is a standalone flake whose luaPath is its own directory,
# so its lua cannot import a path above it. Attribute names there match the
# ones below exactly.
#
# Attributes are bare hex (no leading '#'); `hash` holds the same set prefixed
# with '#' for config formats that require it. `light` holds the light-mode
# counterpart under the same attribute names (and its own `hash`) — see the
# note above lightColors below.
let
  colors = {
    # Surfaces, darkest to lightest.
    bgDeep = "141312"; # sidebars, sunken areas
    bg = "1c1b19"; # default background
    bgAlt = "242320"; # cards, status bars, secondary surfaces
    surface = "2a2825"; # hovered/selected rows
    border = "3a342d";
    divider = "4c4b49"; # thin separators drawn on top of surface (tmux  dividers)

    # Text.
    fg = "d8d0c0";
    fgSoft = "b8b0a0"; # secondary text one step above fgDim (branch names, window titles)
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
    # emphasis-and-attention (paths, cd arguments, folders, workspaces,
    # warnings; ration it: at 8.4:1 it outshines accent), steel = quiet
    # metadata (version pills, flags, interpolation, inlay hints, ANSI blue
    # slot), mauve = language structure, sage = injected/dynamic values (env,
    # interpolation), error = failures only — near-equiluminant with accent
    # (1.35:1 mutual), so always pair it with a glyph or bold, never colour
    # alone.
    #
    # "steel" is a historical name: the slot held a steel blue until 2026-08,
    # when it became magma orange (picked from 20 candidates previewed across
    # yazi/starship/noctalia/nvim). The attribute name stays because it is
    # load-bearing across every consumer and the hand-kept danvim mirror.
    # Magma is also near-equiluminant with accent (1.05:1 mutual) — fine for
    # metadata, but never use it to *contrast against* coral.
    olive = "8a9868";
    gold = "c8b468";
    steel = "ef7f38";
    mauve = "988090";
    sage = "7aa88a";
    error = "e05252";

    # Bright ANSI companions (color9-14 in terminal palettes) — same hue as
    # their normal counterpart above, lightened + saturated the way
    # accentBright steps up from accent. Terminal-only; not used elsewhere.
    oliveBright = "acc66d";
    goldBright = "e3cc75";
    steelBright = "fb9c5f";
    mauveBright = "c586b0";
    sageBright = "84d19f";
  };

  # ── Ember Light ──────────────────────────────────────────────────────────
  # Warm paper with the same coral spark, slot for slot: every attribute above
  # exists here with its *semantics* preserved rather than its lightness. So
  # `bgDeep` is still the sunken surface (a step darker than `bg`, not lighter),
  # `accentBright` is still the higher-contrast accent (6.7:1 vs accent's 4.7:1,
  # reached by going darker), and `accentDim`/`ash` stay decorative-only.
  #
  # Written for noctalia's light mode (noctalia/default.nix builds the Ember
  # palette JSON from both halves); nothing else consumes it yet, so treat the
  # ANSI tail as provisional — no terminal has been retuned against it.
  lightColors = {
    # Surfaces. Ordered the same way as the dark set: bgDeep is the sunken
    # end, divider the most prominent.
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

    # Bright ANSI companions. On light these step *down* in lightness, since
    # "bright" means "more prominent", not "closer to white".
    oliveBright = "44541f";
    goldBright = "6a5306";
    steelBright = "8a3f10";
    mauveBright = "553646";
    sageBright = "27553c";
  };

  withHash = c: c // { hash = builtins.mapAttrs (_: v: "#${v}") c; };
in
withHash colors // { light = withHash lightColors; }
