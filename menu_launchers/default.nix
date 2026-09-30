{ config, pkgs, ... }:

let
  palette = import ../palette.nix;
  vicinae = config.programs.vicinae.package;

  # The two dmenu-style pickers, on PATH by name (hyprland.lua binds them).
  chooseBluetoothDevice = pkgs.writeShellApplication {
    name = "choose-bluetooth-device";
    runtimeInputs = [
      pkgs.bluez
      pkgs.gnused
      pkgs.gawk
      pkgs.libnotify
      vicinae
    ];
    text = builtins.readFile ./scripts/choose_bluetooth_device_from_paired.sh;
  };
  openPaper = pkgs.writeShellApplication {
    name = "open-paper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.poppler-utils
      config.programs.zathura.package
      vicinae
    ];
    text = builtins.readFile ./scripts/open_paper.sh;
  };

  # Theme-picker icon: a coral dot on the theme's background.
  themeIcon =
    c:
    ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="${c.bg}"/><circle cx="32" cy="32" r="13" fill="${c.accent}"/></svg>'';

  # Accents follow palette.nix's ANSI mapping; steel (magma) is both blue and
  # orange.
  emberColors = c: {
    core = {
      background = c.bg;
      foreground = c.fg;
      secondary_background = c.bgAlt;
      border = c.border;
      accent = c.accent;
    };

    accents = {
      blue = c.steel;
      green = c.olive;
      magenta = c.mauve;
      orange = c.steel;
      purple = c.mauve;
      red = c.accent;
      yellow = c.gold;
      cyan = c.sage;
    };
  };
in
{
  # Both use `vicinae dmenu`, which exits 0 even when dismissed with nothing
  # chosen: test its output, never its exit status.
  home.packages = [
    chooseBluetoothDevice
    openPaper
  ];

  # Next to the theme files programs.vicinae.themes writes (meta.icon below).
  xdg.dataFile."vicinae/themes/icons/ember.svg".text = themeIcon palette.hash;
  xdg.dataFile."vicinae/themes/icons/ember-light.svg".text = themeIcon palette.light.hash;

  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = {
        dark = {
          name = "ember";
          icon_theme = "auto";
        };
        light = {
          name = "ember-light";
          icon_theme = "auto";
        };
      };
      launcher_window = {
        size = {
          width = 1536;
          height = 864;
        };
      };
      # Off Alt+space, which is fcitx5's trigger: vicinae reads evdev directly,
      # so both would fire on the same keypress.
      global_shortcuts = {
        toggle = "super+control+space";
      };
      # Clipboard history lives in noctalia; don't record copies twice.
      # `monitoring` is the "Clipboard monitoring" preference (undocumented).
      providers.clipboard = {
        preferences.monitoring = false;
        entrypoints.history.enabled = false;
      };
      font = {
        normal = {
          size = 15;
          family = (import ../fonts.nix).monoWide;
        };
      };
    };
    themes = {
      ember = {
        meta = {
          version = 1;
          name = "Ember";
          description = "Warm graphite monochrome with a single coral spark";
          variant = "dark";
          icon = "icons/ember.svg";
          inherits = "vicinae-dark";
        };

        colors = emberColors palette.hash;
      };

      ember-light = {
        meta = {
          version = 1;
          name = "Ember Light";
          description = "Soft parchment tones with restrained earthy accents";
          variant = "light";
          icon = "icons/ember-light.svg";
          inherits = "vicinae-light";
        };

        colors = emberColors palette.light.hash;
      };
    };
  };

}
