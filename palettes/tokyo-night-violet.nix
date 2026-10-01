# Tokyo Night Violet: Tokyo Night "night" with the ground and text ramp rotated
# to violet (OKLCH h ~296) and the neighbours of the violet accent moved clear
# of it: blue is a soft steel blue, keywords a light rose, error a true red.
#
# The shape is fixed by ./default.nix, which rejects a missing, misspelt or
# malformed entry. Colours are bare lowercase hex.
let
  dark = {
    # Surfaces, darkest to lightest.
    bgDeep = "15111f";
    bg = "1e192b";
    bgAlt = "252034";
    surface = "2d263c";
    border = "3a3050";
    divider = "52476d";

    # Text. muted and fgDim are lighter than Tokyo Night's own comment greys,
    # which fail as text here (1.9:1 and 2.8:1).
    fg = "d5d0ed";
    fgSoft = "b4b0cc";
    fgDim = "9692af";
    muted = "6e6984";

    # Accent: Tokyo Night's magenta, verbatim. Dark text on every step but ash.
    accent = "bb9af7";
    accentBright = "d0b5ff";
    accentDim = "8f6cc9";
    ash = "7357a7";

    # One semantic slot each (see ember.nix): strings/success, emphasis,
    # metadata, language structure, dynamic values, failures.
    olive = "81bd74";
    gold = "e9c167";
    # A real blue, softened: stock 7aa2f7 merges with the accent under
    # protanopia.
    steel = "6ca3cc";
    # Rose, not another violet: it sits next to accent pills in several UIs. It
    # is brighter than the accent, so use it sparingly as text.
    mauve = "fba0b9";
    sage = "5fcab4"; # teal: the calm end of the sage -> gold -> error gradients
    error = "ee5856";

    # Bright ANSI companions.
    oliveBright = "95dc7d";
    goldBright = "f7d67d";
    steelBright = "83b6d7";
    mauveBright = "ffb7c6";
    sageBright = "76e3cf";
  };

  # Lavender paper. Used by noctalia, vicinae and GTK4's light mode; no
  # terminal uses it.
  light = {
    bgDeep = "e6e2f2";
    bg = "f1eff9";
    bgAlt = "e9e6f4";
    surface = "dedaec";
    border = "ccc5df";
    divider = "b5adcd";

    fg = "28223b";
    fgSoft = "47415c";
    fgDim = "66607d";
    muted = "837e9b";

    accent = "7e4bc6";
    accentBright = "6637a5";
    accentDim = "a587db";
    ash = "7c68a8";

    olive = "346620";
    gold = "89660d";
    steel = "236191";
    mauve = "af3d78";
    sage = "0b6f64";
    error = "b00c1e";

    oliveBright = "265313";
    goldBright = "6d5000";
    steelBright = "114d7a";
    mauveBright = "8f275f";
    sageBright = "00564d";
  };

  # Hue-true: red is the error red, blue is steel, and the violet accent takes
  # the magenta slot, as Tokyo Night's own magenta does. mauve (rose) has no
  # slot. To give slot 5 to the rose instead, change the two magenta lines to
  # c.mauve / c.mauveBright and roles.ansi below; no consumer changes.
  ansiFrom = c: {
    red = c.error;
    green = c.olive;
    yellow = c.gold;
    blue = c.steel;
    magenta = c.accent;
    cyan = c.sage;
    brightBlack = c.muted;
    brightGreen = c.oliveBright;
    brightYellow = c.goldBright;
    brightBlue = c.steelBright;
    brightMagenta = c.accentBright;
    brightCyan = c.sageBright;
    brightWhite = "ffffff";
  };
in
{
  inherit dark light;

  # black and white are the two that swap between halves; bright red has no
  # slot of its own (error, one step lighter; on paper, one step darker).
  term = {
    dark = ansiFrom dark // {
      black = dark.bg;
      white = dark.fg;
      brightRed = "fd7468";
    };
    light = ansiFrom light // {
      black = light.fg;
      white = light.bg;
      brightRed = "920014";
    };
  };

  # Colours outside the 25 slots, each with one or two consumers.
  extra = {
    # vicinae's orange accent and danvim's constants and numbers. Tokyo
    # Night's own ff9e64 sits too close to gold.
    orange = {
      dark = "f98924";
      light = "b05200";
    };
    # danvim's types and specials: Tokyo Night's blue1 role, lighter than its
    # 2ac3de to stay clear of steel and sage.
    cyan = "56d6ff";
    # The start page's fog veil.
    fog = "ccc3e1";
    # The Claude statusline's high / xhigh / max effort pills: the accent
    # pushed toward neon pink, stopped short of error.
    heat = [
      "cb76fa"
      "ee60d9"
      "ec37ad"
    ];
    # The start page's five-stop grade for the painting; the last stop stays
    # darker than fg.
    artRamp = [
      "0a0912"
      "1e1a2f"
      "443961"
      "816fa4"
      "bcabd5"
    ];
  };

  # Which name plays which part, stated once for both halves.
  roles = {
    # role -> ANSI colour name (IPython, prompt_toolkit, glamour). Six hues
    # for nine roles, shared the way Tokyo Night's own syntax shares them.
    ansi = {
      accent = "magenta";
      accentBright = "brightMagenta";
      definition = "blue"; # Tokyo Night: functions blue
      failure = "red"; # a real red exists here
      structure = "magenta"; # Tokyo Night: keywords violet
      metadata = "cyan"; # Tokyo Night: builtins and types cyan
      emphasis = "cyan"; # types, decorators: same family upstream
      value = "yellow"; # Tokyo Night's constant orange has no ANSI slot
      string = "green";
    };

    # Material role -> slot name (noctalia shell, greeter, dart panel states).
    material = {
      primary = "accent";
      secondary = "gold";
      tertiary = "sage";
      hover = "accentBright";
    };

    # hue name -> slot name (vicinae accents; its orange is extra.orange).
    hues = {
      red = "error";
      yellow = "gold";
      green = "olive";
      cyan = "sage";
      blue = "steel";
      purple = "accent";
      magenta = "mauve";
    };

    # tmux copy mode. Not sage against mauve as in Ember: teal and rose merge
    # under deuteranopia, and colour is the only cue there.
    search = {
      match = "sage";
      current = "gold";
    };
  };

  # Everything that is not a colour.
  meta = {
    name = "Tokyo Night Violet";
    slug = "tokyo-night-violet";
    description = "Tokyo Night on a violet ground, with a lavender accent";
    light = {
      name = "Tokyo Night Violet Light";
      slug = "tokyo-night-violet-light";
      description = "Lavender paper with dark violet ink";
    };
    gtk = {
      package = pkgs: pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
      # adw-gtk3's gtk-4.0 sheet is a copy of libadwaita's own; importing it as
      # user CSS would shadow the real one inside libadwaita apps.
      gtk4Import = false;
      # Every adw-gtk3 / libadwaita colour is a named-colour reference.
      paletteCss = {
        gtk3 = true; # GTK3 apps and, via QT_QPA_PLATFORMTHEME=gtk3, Qt6
        gtk4 = true; # libadwaita apps and plain GTK4 apps
      };
    };
    # Only seen where ~/.config/gtk-4.0/gtk.css is not read.
    adwaitaAccent = "purple";
    cursor = {
      package = pkgs: pkgs.catppuccin-cursors.mochaMauve;
      name = "catppuccin-mocha-mauve-cursors";
      size = 24; # the theme ships 12, 18, 24, 30, …; not 20
    };
    icons = {
      package = pkgs: pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };
    nvim.family = "tokyonight";
    # kitty's cursor trail: violet body, deeper violet edge.
    trail = {
      fill = "accent";
      rim = "accentDim";
    };
  };
}
