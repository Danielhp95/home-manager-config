{
  inputs,
  pkgs,
  config,
  ...
}:
let
  # Cycle TLP's power mode: auto (follows AC/battery) -> forced battery (low
  # power) -> forced AC (performance) -> auto. TLP records a forced mode in
  # /run/tlp/manual_mode; absence means auto. sudo is passwordless for tlp
  # (see security.sudo.extraRules in configuration.nix).
  tlp-mode = pkgs.writeShellScriptBin "tlp-mode" ''
    manual=$(cat /run/tlp/manual_mode 2>/dev/null || true)
    case "$manual" in
      "")
        sudo tlp bat >/dev/null
        ${pkgs.libnotify}/bin/notify-send -a tlp-mode "Power mode" "Low power (forced battery)"
        ;;
      BAT|bat)
        sudo tlp ac >/dev/null
        ${pkgs.libnotify}/bin/notify-send -a tlp-mode "Power mode" "Performance (forced AC)"
        ;;
      *)
        sudo tlp start >/dev/null
        ${pkgs.libnotify}/bin/notify-send -a tlp-mode "Power mode" "Auto (follows power source)"
        ;;
    esac
  '';
in
{
  home.packages = [
    tlp-mode
    # logcli for `dart logs` (the dart-plugin Logs button and terminal use).
    # Until the switch lands, the plugin falls back to the sai FHS env's store
    # path (see dart-plugin/panel.luau openLogs).
    pkgs.grafana-loki
  ];

  # dart-plugin: noctalia v5 Luau plugin showing DART training runs in the bar
  # (dart logo + running count; panel with per-run cancel/suspend/resume/delete).
  # Linked out-of-store so edits to ./dart-plugin hot-reload the running shell
  # (noctalia file-watches .luau files) without a rebuild. Swap to
  # `.source = ./dart-plugin;` for a pure store copy once it stabilises.
  # NOTE first switch: if `~/.local/share/noctalia/plugins/dart` already exists
  # from the pre-nix dev install, `rm` it first or activation fails.
  xdg.dataFile."noctalia/plugins/dart".source =
    config.lib.file.mkOutOfStoreSymlink "/home/dani/nix_config/noctalia/dart-plugin";

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # Run noctalia as a systemd user service (restarts automatically on config changes)
    systemd.enable = true;

    # Declarative defaults for noctalia v5 (written to ~/.config/noctalia/config.toml).
    # Runtime tweaks via the settings UI still land in settings.json and win over these.
    # Schema reference: example.toml in the noctalia repo.
    settings = {
      shell = {
        font_family = "Adwaita Sans";
        telemetry_enabled = false;
        avatar_path = "~/.face";
      };

      theme = {
        mode = "dark";
        # Derive shell colors from the current wallpaper (matugen-style).
        source = "wallpaper";
        # Propagate wallpaper colors to other apps' configs.
        templates = {
          builtin_ids = [
            "cava"
            "hyprland"
          ];
          community_ids = [ "telegram" ];
        };
      };

      # Used by nightlight sunset/sunrise scheduling (and weather widget).
      location = {
        address = "coruna";
        auto_locate = true;
      };

      nightlight.enabled = true;

      control_center.shortcuts = [
        # NOTE: like the bar widget, the wifi shortcut needs NetworkManager or
        # wpa_supplicant, so it's inert on this connman+iwd setup.
        { type = "wifi"; }
        { type = "nightlight"; }
        { type = "bluetooth"; }
        { type = "notification"; }
        # NOTE: the power_profile shortcut spoke to power-profiles-daemon,
        # which is now disabled in favour of TLP (see tlp_mode bar widget).
        { type = "dark_mode"; }
      ];

      plugins.source = [
        {
          name = "official";
          kind = "git";
          location = "https://github.com/noctalia-dev/official-plugins";
          auto_update = true;
        }
        {
          name = "community";
          kind = "git";
          location = "https://github.com/noctalia-dev/community-plugins";
          auto_update = true;
        }
      ];
      # Plugins are opt-in per id even when present on disk. dani/dart is the
      # local dart run-manager plugin linked into ~/.local/share/noctalia/plugins
      # (see xdg.dataFile above). NB: `noctalia msg plugins enable/disable` and
      # the GUI write this same key into the runtime overrides file
      # (~/.local/state/noctalia/settings.toml), which replaces this array
      # wholesale — delete the [plugins] block there if this list stops applying.
      plugins.enabled = [ "dani/dart" ];

      wallpaper = {
        enabled = true;
        directory = "~/nix_config/wallpapers";
        fill_mode = "crop";
      };

      notification = {
        enable_daemon = true;
      };

      # Floating pill bar: inset from the screen edges, rounded, translucent,
      # widgets in capsules. Named "default" to override noctalia's built-in
      # bar; any other name would spawn a second bar alongside it.
      bar.default = {
        position = "top";
        thickness = 36;
        background_opacity = 0.85;
        radius = 18;
        margin_ends = 8; # inset from each end of the bar
        margin_edge = 6; # gap to the screen edge -> floating bar
        padding = 12;
        widget_spacing = 8;
        shadow = true;
        capsule = true;
        capsule_fill = "surface_variant";
        capsule_opacity = 0.8;

        start = [
          "clock"
          "sysmon"
          "active_window"
          "media"
        ];
        center = [ "workspaces" ];
        end = [
          "tray"
          "notifications"
          "dart"
          "battery"
          "volume"
          "brightness"
          "tlp_mode"
          "bluetooth"
          "wifi_tui"
          "control-center"
        ];
      };

      # The laptop panel (card1-eDP-1) is driven by intel_backlight; force the
      # sysfs backlight backend so noctalia never falls back to ddc/none.
      brightness = {
        monitor."eDP-1".backend = "backlight";
      };

      widget = {
        # Show workspace names instead of numbers; names are set to nerdfont
        # glyphs via workspace rules in hyprland.lua.
        workspaces = {
          display = "name";
        };

        clock = {
          format = "{:%H:%M %a, %b %d}";
          tooltip_format = "{:%A, %B %d, %Y}";
        };

        # noctalia's builtin network widget only speaks NetworkManager /
        # wpa_supplicant; this setup uses connman+iwd, so open impala instead.
        # TLP power mode, styled like wifi_tui: left-click cycles
        # auto -> forced low power -> forced performance -> auto (with a
        # notification), right-click opens tlp-stat in a terminal.
        tlp_mode = {
          type = "custom_button";
          glyph = "bolt";
          tooltip = "Power mode (TLP) — click: cycle, right-click: status";
          command = "tlp-mode";
          right_command = "kitty --hold -e sudo tlp-stat -s";
        };

        # Icon + connected device name in the bar; hovering lists each
        # connected device with its battery %. Left-click opens the
        # control-center bluetooth tab, right-click toggles bluetooth power.
        bluetooth = {
          show_label = true;
          hide_when_no_connected_device = false;
        };

        wifi_tui = {
          type = "custom_button";
          glyph = "wifi";
          tooltip = "Wi-Fi (impala)";
          command = "kitty -e impala";
        };

        # DART run manager (local Luau plugin, see dart-plugin/). Same alias
        # idiom as the custom_buttons above: bare "dart" in the bar list
        # resolves through this table to the plugin widget entry.
        dart = {
          type = "dani/dart:widget";
        };
      };

      dock.enabled = false;
    };
  };
}
