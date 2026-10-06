{
  config,
  lib,
  pkgs,
  ...
}:

let
  palette = import ../../palette;
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

  # Theme-picker icon: an accent dot on the theme's background.
  themeIcon =
    c:
    ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="${c.bg}"/><circle cx="32" cy="32" r="13" fill="${c.accent}"/></svg>'';

  # vicinae names its accents by hue: the palette's roles.hues says which slot
  # carries each one, and its orange is extra.orange.
  themeColors = roles: c: {
    core = {
      background = c.bg;
      foreground = c.fg;
      secondary_background = c.bgAlt;
      inherit (c) border accent;
    };

    accents = builtins.mapAttrs (_: slot: c.${slot}) roles.hues // {
      orange = c.extra.orange;
    };
  };

  # A dark and a light theme per palette. Every palette is installed, so the
  # picker lists them all; settings.theme below follows the selected one.
  themesOf =
    { meta, roles, ... }@q:
    {
      ${meta.slug} = {
        meta = {
          version = 1;
          inherit (meta) name description;
          variant = "dark";
          icon = "icons/${meta.slug}.svg";
          inherits = "vicinae-dark";
        };

        colors = themeColors roles q.hash;
      };

      ${meta.light.slug} = {
        meta = {
          version = 1;
          inherit (meta.light) name description;
          variant = "light";
          icon = "icons/${meta.light.slug}.svg";
          inherits = "vicinae-light";
        };

        colors = themeColors roles q.light.hash;
      };
    };

  # Next to the theme files programs.vicinae.themes writes (meta.icon above).
  iconsOf =
    { meta, ... }@q:
    {
      "vicinae/themes/icons/${meta.slug}.svg".text = themeIcon q.hash;
      "vicinae/themes/icons/${meta.light.slug}.svg".text = themeIcon q.light.hash;
    };
in
{
  # Both use `vicinae dmenu`, which exits 0 even when dismissed with nothing
  # chosen: test its output, never its exit status.
  home.packages = [
    chooseBluetoothDevice
    openPaper
  ];

  xdg.dataFile = lib.concatMapAttrs (_: iconsOf) palette.all;

  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = {
        dark = {
          name = palette.meta.slug;
          icon_theme = "auto";
        };
        light = {
          name = palette.meta.light.slug;
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
          family = (import ../../fonts.nix).monoWide;
        };
      };
    };
    themes = lib.concatMapAttrs (_: themesOf) palette.all;
  };

}
