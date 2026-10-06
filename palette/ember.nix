# The Ember palette: warm graphite with a coral spark, in the family of the
# WhiteSur-Dark-orange GTK/Qt theme (home/hyprland/theming.nix).
#
# One hand-kept copy: danvim's palette.lua embeds these values as its fallback
# for builds without the nix_config override (../pkgs/danvim.nix).
#
# The shape is fixed by ./lib.nix, which rejects a missing, misspelt or
# malformed entry. Colours are bare lowercase hex.
let
  dark = {
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
  light = {
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

  # Ember has no true red, blue or magenta: the terminal's red IS the accent
  # (error has no ANSI slot), blue is magma, magenta is mauve.
  ansiFrom = c: {
    red = c.accent;
    green = c.olive;
    yellow = c.gold;
    blue = c.steel;
    magenta = c.mauve;
    cyan = c.sage;
    brightBlack = c.muted;
    brightRed = c.accentBright;
    brightGreen = c.oliveBright;
    brightYellow = c.goldBright;
    brightBlue = c.steelBright;
    brightMagenta = c.mauveBright;
    brightCyan = c.sageBright;
    brightWhite = "ffffff";
  };
in
{
  inherit dark light;

  # The 16 ANSI colours by name (kitty, ghostty, the Linux console, noctalia's
  # terminal templates). black and white are the two that swap between halves.
  term = {
    dark = ansiFrom dark // {
      black = dark.bg;
      white = dark.fg;
    };
    light = ansiFrom light // {
      black = light.fg;
      white = light.bg;
    };
  };

  # Colours outside the 25 slots, each with one or two consumers.
  extra = {
    # noctalia's error role; the error slot itself in each half.
    urgent = {
      dark = "e05252";
      light = "b3261e";
    };
    # Where a consumer wants an orange apart from blue (vicinae); in Ember both
    # are magma, so this is steel in each half.
    orange = {
      dark = "ef7f38";
      light = "a84e16";
    };
    # danvim's tokyonight family paints types with it; under Ember nothing
    # reads it. Sage, the slot nearest that hue.
    cyan = "7aa88a";
    # The start page's fog veil.
    fog = "d8c6b2";
    # Three steps hotter than accent: the Claude statusline's high / xhigh /
    # max effort pills.
    heat = [
      "e86e3a"
      "f55a2e"
      "ff422e"
    ];
    # The start page's five-stop grade for the painting, black rock to
    # brightest sky; the last stop stays darker than fg.
    artRamp = [
      "0c0b0a"
      "221c19"
      "4a3b33"
      "8a7061"
      "c8ab94"
    ];
  };

  # Which name plays which part, stated once for both halves.
  roles = {
    # role -> ANSI colour name, for programs that can only name terminal slots
    # (IPython, prompt_toolkit, glamour).
    ansi = {
      accent = "red"; # the UI hero: selected row, headings, pills
      accentBright = "brightRed";
      definition = "red"; # names being defined: class, function
      failure = "brightRed"; # error has no slot; bright red is the nearest
      structure = "magenta"; # keywords, tags
      metadata = "blue"; # builtins, module paths
      emphasis = "yellow"; # types, decorators
      value = "cyan"; # constants, numbers, escapes
      string = "green";
    };

    # Material role -> slot name (noctalia shell, greeter, dart panel states).
    material = {
      primary = "accent";
      secondary = "gold";
      tertiary = "sage";
      hover = "accentBright";
    };

    # hue name -> slot name, for programs that want a colour by its hue
    # (vicinae accents; its orange is extra.orange). Ember has neither a blue
    # nor a true red.
    hues = {
      red = "accent";
      yellow = "gold";
      green = "olive";
      cyan = "sage";
      blue = "steel";
      purple = "mauve";
      magenta = "mauve";
    };

    # tmux copy mode: slot behind every search match, and behind the current
    # one (tmux's own defaults are cyan and magenta: the same two here).
    search = {
      match = "sage";
      current = "mauve";
    };
  };

  # Everything that is not a colour. Consumers read it as `palette.meta`.
  # `package` values are functions of pkgs, so this file imports without it.
  meta = {
    name = "Ember";
    slug = "ember";
    description = "Warm graphite monochrome with a single coral spark";
    light = {
      name = "Ember Light";
      slug = "ember-light";
      description = "Soft parchment tones with restrained earthy accents";
    };
    gtk = {
      package = pkgs: pkgs.whitesur-gtk-theme.override { themeVariants = [ "orange" ]; };
      name = "WhiteSur-Dark-orange";
      gtk4Import = true;
      # WhiteSur's CSS is compiled to literal hex: gtk3 would do nothing, and
      # gtk4 would recolour only libadwaita apps (which WhiteSur never reaches).
      paletteCss = {
        gtk3 = false;
        gtk4 = false;
      };
    };
    # libadwaita's accent-color: named colours only, the nearest to `accent`.
    adwaitaAccent = "orange";
    cursor = {
      package = pkgs: pkgs.bibata-cursors;
      name = "Bibata-Modern-Amber";
      size = 20;
    };
    icons = {
      package = pkgs: pkgs.papirus-icon-theme;
      name = "Papirus";
    };
    # Which base colourscheme danvim loads under its own overrides.
    nvim.family = "ember";
    # kitty's cursor trail: coral body, magma edge.
    trail = {
      fill = "accent";
      rim = "steel";
    };
  };
}
