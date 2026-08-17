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

    # localsend-plugin's three helpers. noctalia itself cannot do any of this:
    # it has no UDP sockets (socat carries multicast discovery), it cannot be a
    # Wayland drop target (ripdrag provides the drop window), and it has no
    # file dialog (zenity provides the pickers).
    pkgs.socat
    pkgs.ripdrag
    pkgs.zenity
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

  # localsend-plugin: send files over LocalSend without opening the app —
  # drop target / file picker / clipboard on one side, multicast device
  # discovery and the v2 upload handshake on the other. Same out-of-store
  # symlink so .luau edits hot-reload without a rebuild.
  # NOTE same first-switch trap as above: if the path already exists as a
  # hand-made symlink, `rm` it before switching or activation fails.
  xdg.dataFile."noctalia/plugins/localsend".source =
    config.lib.file.mkOutOfStoreSymlink "/home/dani/nix_config/noctalia/localsend-plugin";

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

      # Idle locking. Nothing else on this system does it any more: hyprlock is
      # gone (hyprland/default.nix) and there is no hypridle/swayidle, so these
      # three behaviours are the whole story — before this, the screen locked on
      # lid close and on suspend and at no other time.
      #
      # `lock-and-suspend` stays off on purpose: idling away from the machine
      # must not take down the local q_landscape dashboards, a vizdoom client or
      # an ssh session. Suspend when it does happen still locks first, via
      # lockscreen.lock_before_suspend below.
      idle = {
        behavior.lock = {
          enabled = true;
          timeout = 600; # 10 min
        };
        behavior."screen-off" = {
          enabled = true;
          timeout = 660; # 11 min — a minute of locked screen before it blanks
        };
        behavior."lock-and-suspend".enabled = false;
      };

      # noctalia owns the lockscreen now that hyprlock is removed, so the
      # suspend interlock is stated here rather than left to the default.
      lockscreen = {
        enabled = true;
        lock_before_suspend = true;
      };

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

      # auto_update is plugins-wide since the 2026-07 noctalia bump (it used to
      # be a per-source key). Off: it made the bar git-fetch both plugin
      # sources at every session start — network-dependent login latency that
      # stalled offline. Update deliberately from the plugin manager instead.
      # The local dani/* plugins are out-of-store symlinks and unaffected.
      plugins.auto_update = false;
      plugins.source = [
        {
          name = "official";
          kind = "git";
          location = "https://github.com/noctalia-dev/official-plugins";
        }
        {
          name = "community";
          kind = "git";
          location = "https://github.com/noctalia-dev/community-plugins";
        }
      ];
      # Plugins are opt-in per id even when present on disk. dani/dart is the
      # local dart run-manager plugin linked into ~/.local/share/noctalia/plugins
      # (see xdg.dataFile above). NB: `noctalia msg plugins enable/disable` and
      # the GUI write this same key into the runtime overrides file
      # (~/.local/state/noctalia/settings.toml), which replaces this array
      # wholesale — delete the [plugins] block there if this list stops applying.
      plugins.enabled = [
        "dani/dart"
        "dani/localsend"
      ];

      wallpaper = {
        enabled = true;
        directory = "~/nix_config/wallpapers";
        fill_mode = "crop";
      };

      notification = {
        enable_daemon = true;

        # batsignal fires its "full" notification (-f 97, see hyprland/default.nix)
        # every time the charger blips, which on a flaky plug means a toast every
        # few seconds. Drop anything it reports at 95% or above: the app name
        # narrows it to batsignal, and match_content is an ECMAScript regex run
        # (case-insensitively) over the summary and body — batsignal's body is
        # always "Battery level: NN%". Low/critical warnings sit well under 95
        # and still come through.
        filter.batsignal-near-full = {
          enabled = true;
          match = "batsignal";
          match_content = "Battery level: (9[5-9]|100)%";
          show_toast = false;
          save_history = false;
          play_sound = false;
        };
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
          "localsend"
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

        # LocalSend sender (local Luau plugin, see localsend-plugin/).
        # Left-click opens the send panel, right-click opens a drop target.
        localsend = {
          type = "dani/localsend:widget";
        };
      };

      dock.enabled = false;
    };
  };
}
