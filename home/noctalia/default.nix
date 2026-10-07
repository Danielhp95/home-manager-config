# The noctalia shell: its package, palettes and general settings. The bar and
# its widgets, the plugins and the battery wording are the files beside this.
{
  inputs,
  pkgs,
  lib,
  theme,
  host,
  ...
}:
let
  p = theme;
  material = import ./material.nix { inherit lib; };
  # A palette's file stem under ~/.config/noctalia/palettes, which is also the
  # name the settings GUI shows and `theme.custom_palette` selects.
  stem = palette: builtins.replaceStrings [ " " ] [ "" ] palette.meta.name;

  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./bar.nix
    ./plugins.nix
    ./stormlight.nix
  ];

  # For shell.avatar_path. The greeter can't read ~ (0700) and gets the same
  # image through AccountsService (nixos/greeter.nix).
  home.file.".face".source = pkgs.avatar;

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;

    # A switch restarts the service when the config or palette changes.
    systemd.enable = true;

    # ~/.config/noctalia/palettes/<stem>.json, one per palette: a name saved
    # by the settings GUI then always has a file, whichever is selected below.
    customPalettes = lib.mapAttrs' (
      _: palette: lib.nameValuePair (stem palette) (material.shell palette)
    ) p.all;

    # config.toml (schema: example.toml in the noctalia repo). Settings-GUI
    # changes land in ~/.local/state/noctalia/settings.toml and override these,
    # arrays wholesale.
    settings = {
      shell = {
        font_family = theme.fonts.ui;
        telemetry_enabled = false;
        avatar_path = "~/.face";
        # The clipboard history (mod+CONTROL+V); vicinae's is off in
        # ../vicinae/ so copies aren't recorded twice.
        clipboard_enabled = true;
        window_switcher.mru = true;
        # Push wallpaper changes to the greeter; passwordless via the Polkit
        # rule in nixos/greeter.nix.
        greeter_sync.auto_sync = true;

        # Every capture opens the annotation editor; Enter/Done copies to the
        # clipboard only, Save / Ctrl+S writes to `directory`.
        screenshot = {
          annotate = true;
          save_to_file = false;
          copy_to_clipboard = true;
        };
      };

      theme = {
        mode = "dark";
        # The palette (customPalettes above) rather than wallpaper-derived
        # colours, so the shell matches every other app; both halves are real,
        # so the dark_mode toggle switches to its light half.
        source = "custom";
        custom_palette = stem p;
        # Propagate the palette to other apps' configs.
        templates = {
          # Not "cava" (not installed; its apply.sh exits 1) or "hyprland" (its
          # apply.sh can't append to the read-only hyprland.lua).
          builtin_ids = [ ];
          community_ids = [ "telegram" ];
        };
      };

      # Feeds the nightlight schedule and the weather widget.
      location.auto_locate = true;

      # Off, as last chosen in the control center.
      nightlight.enabled = false;

      weather = {
        enabled = true;
        unit = "celsius";
      };

      # The system's only idle handling (no hypridle). lock-and-suspend stays off:
      # idling must not take down local dashboards or ssh sessions. A suspend
      # still locks first (lockscreen.lock_before_suspend).
      idle = {
        # A configured behavior replaces noctalia's default wholesale, so each
        # needs its `action`; without it noctalia skips the behavior.
        behavior.lock = {
          enabled = true;
          action = "lock";
          timeout = 600; # 10 min
        };
        behavior."screen-off" = {
          enabled = true;
          action = "screen_off";
          timeout = 660; # 11 min — a minute of locked screen before it blanks
        };
        behavior."lock-and-suspend" = {
          enabled = false;
          action = "lock_and_suspend";
        };
      };

      lockscreen = {
        enabled = true;
        lock_before_suspend = true;
      };

      control_center.shortcuts = [
        { type = "wifi"; }
        { type = "nightlight"; }
        { type = "bluetooth"; }
        { type = "notification"; }
        { type = "dark_mode"; }
        { type = "noctalia/screen_recorder:toggle"; }
      ];

      wallpaper = {
        enabled = true;
        directory = "~/nix_config/wallpapers"; # the live checkout, in the ~ form noctalia keeps
        fill_mode = "crop";
      };

      notification = {
        enable_daemon = true;
        # Mutes notification sounds only (audio.enable_sounds would also kill
        # the volume/screenshot/plug sounds). Filters are first-match and "^"
        # matches everything, so a per-app filter must sort before this one.
        filter.silent = {
          match_content = "^";
          play_sound = false;
        };
      };

      # The built-in panel has a sysfs backlight; pin that backend so noctalia
      # never falls back to ddc/none.
      brightness.monitor.${host.panel.output}.backend = "backlight";

      dock.enabled = false;
    };
  };
}
