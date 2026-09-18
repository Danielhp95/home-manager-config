{
  inputs,
  pkgs,
  config,
  ...
}:
let
  p = import ../palette.nix;

  # One half (dark or light) of a noctalia custom palette. The file format is
  # two of these under "dark"/"light": m* slots drive the whole shell, and the
  # `terminal` block feeds the terminal templates. The slot mapping is straight
  # off palette.nix's semantics — coral is the primary, gold and sage are the
  # two secondaries, and the surface ramp supplies surface / surfaceVariant /
  # outline. `hover` gets accentBright, which is the one place the hotter coral
  # is meant to show up.
  #
  # ansiBlack/ansiWhite are passed in because they are the two ANSI slots whose
  # dark and light halves genuinely swap: "black" is the darkest colour in the
  # set and "white" the lightest, which is the background on dark and the
  # foreground on light. The rest of the ANSI block mirrors kitty/kitty.conf.
  emberHalf =
    {
      c,
      ansiBlack,
      ansiWhite,
    }:
    {
      mPrimary = c.hash.accent;
      mOnPrimary = c.hash.bg;
      mSecondary = c.hash.gold;
      mOnSecondary = c.hash.bg;
      mTertiary = c.hash.sage;
      mOnTertiary = c.hash.bg;
      mError = c.hash.error;
      mOnError = c.hash.bg;
      mSurface = c.hash.bg;
      mOnSurface = c.hash.fg;
      mHover = c.hash.accentBright;
      mOnHover = c.hash.bg;
      mSurfaceVariant = c.hash.surface;
      mOnSurfaceVariant = c.hash.fgSoft;
      mOutline = c.hash.border;
      mShadow = c.hash.bgDeep;
      terminal = {
        background = c.hash.bg;
        foreground = c.hash.fg;
        cursor = c.hash.accent;
        cursorText = c.hash.bg;
        selectionBg = c.hash.border;
        selectionFg = c.hash.fg;
        normal = {
          black = ansiBlack;
          red = c.hash.accent;
          green = c.hash.olive;
          yellow = c.hash.gold;
          blue = c.hash.steel;
          magenta = c.hash.mauve;
          cyan = c.hash.sage;
          white = ansiWhite;
        };
        bright = {
          black = c.hash.muted;
          red = c.hash.accentBright;
          green = c.hash.oliveBright;
          yellow = c.hash.goldBright;
          blue = c.hash.steelBright;
          magenta = c.hash.mauveBright;
          cyan = c.hash.sageBright;
          white = "#ffffff";
        };
      };
    };

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

    # jrohland/claudecode gates its service on `commandExists("jq")`. jq was
    # only ever reachable as an interpolated store path (hyprland/default.nix),
    # never on PATH, so the plugin would have silently reported no data.
    pkgs.jq

    # rylos/tailnet resolves its default Taildrop directory with `xdg-user-dir
    # DOWNLOAD`; without it the setting falls back to an unwritable path.
    pkgs.xdg-user-dirs
  ];

  # The Ember palette as a noctalia custom palette. Custom palettes are read
  # from ~/.config/noctalia/palettes/<name>.json (the settings UI lists the
  # directory; `theme.custom_palette` below selects by file stem) — note it is
  # *palettes*, not the stale `colorschemes` directory an older version made.
  # Generated from palette.nix so the shell can never drift from the terminals.
  xdg.configFile."noctalia/palettes/Ember.json".text = builtins.toJSON {
    dark = emberHalf {
      c = p;
      ansiBlack = p.hash.bg;
      ansiWhite = p.hash.fg;
    };
    light = emberHalf {
      c = p.light;
      ansiBlack = p.light.hash.fg;
      ansiWhite = p.light.hash.bg;
    };
  };

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
        # noctalia is the clipboard history (panel: mod+CONTROL+V in
        # hyprland.lua); vicinae's clipboard monitoring is switched off in
        # menu_launchers/ so the two don't both record every copy.
        clipboard_enabled = true;
        # Alt+Tab switcher lists windows most-recently-used first.
        window_switcher.mru = true;

        # Screenshots replace hyprshot + satty: every capture opens the
        # annotation editor, and Enter/Done copies to the clipboard only.
        # Nothing lands in ~/Pictures unless Save / Ctrl+S is pressed
        # explicitly (that still writes there, to `directory`).
        screenshot = {
          annotate = true;
          save_to_file = false;
          copy_to_clipboard = true;
        };
      };

      theme = {
        mode = "dark";
        # Ember rather than wallpaper-derived colors (source = "wallpaper",
        # matugen-style): the wallpaper rotates and the shell was the one
        # surface in the system not speaking the palette every other app does.
        # "custom" reads ~/.config/noctalia/palettes/Ember.json, written from
        # palette.nix by the xdg.configFile above; it carries both halves, so
        # the control-center dark_mode toggle has a real light theme to switch
        # to instead of an auto-derived one.
        source = "custom";
        custom_palette = "Ember";
        # Propagate wallpaper colors to other apps' configs.
        templates = {
          # No "cava": cava isn't installed, and its template's apply.sh
          # exits 1 on every palette apply ("cava config file not found").
          builtin_ids = [
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
      plugins.auto_update = "none";
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

        # Community plugins. The source clone is a `blob:none` partial clone and
        # noctalia's git calls do not lazy-fetch: if a newly enabled plugin shows
        # up empty, pre-warm its blobs with
        #   git -C ~/.local/state/noctalia/plugins/sources/community/repo \
        #     ls-tree -r HEAD -- <dir> | awk '{print $3}' | git -C ... cat-file --batch-check
        # before enabling. Same trap makes the whole community catalog vanish
        # from the list after a bare `git fetch` until catalog.toml is fetched.

        # Tailscale status/control: peers, exit nodes, IP copy, Taildrop, and a
        # launcher provider. Needs tailscale + ssh (system profile), gio and
        # xdg-open (already present), and xdg-user-dirs (added to home.packages
        # above for its Taildrop directory default).
        "rylos/tailnet"

        # Claude Code subscription usage: rate limits, token burn, cost, daily
        # activity, per-model breakdown. Gates on jq and curl at runtime — jq was
        # NOT in any profile before this (only interpolated as a store path in
        # hyprland/default.nix), hence the home.packages entry above.
        "jrohland/claudecode"

        # Searchable Hyprland keybindings. Reads binds from the *running*
        # compositor over `hyprctl`, which is the only reason it works here:
        # anything that parses hyprland.conf is useless under configType = "lua"
        # (see hyprland/default.nix), so blackbartblues/keymap is deliberately
        # not used.
        "kenn/keybind-cheatsheet"

        # Enabled through the GUI before this list existed, so it was only ever
        # live via the settings.toml override. Recorded here so the nix list is
        # the complete set. Overlaps jrohland/claudecode (usage telemetry);
        # drop whichever earns less bar space.
        "lowcache/claude-companion"
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

      # Floating pills: the bar's own background is fully transparent (its
      # drop shadow is scaled by background_opacity, so no orphaned shadow
      # strip) and every widget is its own solid capsule, with wallpaper
      # showing through between them. Named "default" to override noctalia's
      # built-in bar; any other name would spawn a second bar alongside it.
      bar.default = {
        position = "top";
        thickness = 36;
        background_opacity = 0.0;
        radius = 18;
        margin_ends = 8; # inset from each end of the bar
        # Vertical air around the floating bar. `margin_edge` is the gap to the
        # anchored edge (top), `margin_opposite_edge` the gap on the far side
        # (bottom, taken out of the space the bar reserves). 5/1 rather than
        # 6/0: the bar sat a pixel low against the screen edge.
        margin_edge = 5;
        margin_opposite_edge = 1;
        padding = 12;
        widget_spacing = 8;
        shadow = true;
        capsule = true;
        capsule_fill = "surface_variant";
        capsule_opacity = 1.0;
        # Capsule cross-size as a fraction of bar thickness (default 0.76).
        # With the bar background gone the pills *are* the bar, so a bit
        # thicker keeps them from reading skinnier than the old pill.
        capsule_thickness = 0.88;

        # Plain lanes, no capsule_group: every widget draws its own pill. The
        # grouped three-island version was tried and rejected (2026-09-16) —
        # dart belongs next to the workspaces, and the right side reads better
        # as separate pills.
        start = [
          "home"
          "clock"
          "sysmon"
          # Reads as a meter, so it sits with sysmon rather than in the status
          # lane on the right.
          "claudecode"
          "active_window"
          "media"
        ];
        center = [
          "workspaces"
          "dart"
          "localsend"
        ];
        end = [
          "tray"
          "privacy"
          "notifications"
          "battery"
          "volume"
          "brightness"
          "tlp_mode"
          # Next to bluetooth: both are "is this radio/link up" pills.
          "tailnet"
          "bluetooth"
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
        # glyphs via workspace rules in hyprland.lua. `display` was renamed to
        # label_source + show_labels; the old key still worked but was migrated
        # in memory with a deprecation warning on every load.
        workspaces = {
          label_source = "name";
          show_labels = true;
          # Only the focused monitor's active workspace gets focused_color; the
          # active workspace on other monitors falls back to occupied_color
          focused_output_only = true;
        };

        clock = {
          format = "{:%H:%M %a, %b %d}";
          tooltip_format = "{:%A, %B %d, %Y}";
        };

        # Leftmost button: drops the control centre's Home tab (avatar, uptime,
        # weather, media, the control_center.shortcuts above) down from the bar.
        # It has to be a custom_button rather than a second `control-center`
        # widget because that widget type has no option for which tab to open —
        # it reopens wherever you last were, and this button is specifically the
        # home dropdown.
        home = {
          type = "custom_button";
          glyph = "home";
          tooltip = "Home";
          actions.left = "exec noctalia msg panel-toggle control-center home";
        };

        # TLP power mode as a custom_button: left-click cycles
        # auto -> forced low power -> forced performance -> auto (with a
        # notification), right-click opens tlp-stat in a terminal.
        #
        # `actions.left`/`actions.right` rather than the old `command`/
        # `right_command`: those are gesture bindings now, and noctalia was
        # migrating them in memory on every load with a deprecation warning.
        tlp_mode = {
          type = "custom_button";
          glyph = "bolt";
          tooltip = "Power mode (TLP) — click: cycle, right-click: status";
          actions.left = "exec tlp-mode";
          actions.right = "exec kitty --hold -e sudo tlp-stat -s";
        };

        # Icon + connected device name in the bar; hovering lists each
        # connected device with its battery %. Left-click opens the
        # control-center bluetooth tab, right-click toggles bluetooth power.
        bluetooth = {
          show_label = true;
          hide_when_no_connected_device = false;
        };

        # Mic / camera / screen-share indicator: voxtype (mod+V), the screen
        # recorder and xdph screencasts all capture without any other visible
        # sign. Hidden while nothing is capturing.
        privacy = {
          hide_inactive = true;
        };

        # NOTE: there is deliberately no wifi widget here. noctalia's builtin
        # network widget only speaks NetworkManager / wpa_supplicant and this
        # setup is connman+iwd, and the impala custom_button that stood in for
        # it was redundant with iwgtk's tray icon (iwgtk-indicator, autostarted
        # via xdg-desktop-autostart — see configuration.nix).

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

        # Tailscale link state (rylos/tailnet). The plugin also registers a
        # launcher provider and a "toggle" shortcut, so this pill is the
        # convenience, not the only way in.
        tailnet = {
          type = "rylos/tailnet:bar";
        };

        # Claude Code subscription usage (jrohland/claudecode). Stays blank
        # until jq is on the shell's PATH — see the home.packages note above.
        claudecode = {
          type = "jrohland/claudecode:pill";
        };

        # kenn/keybind-cheatsheet deliberately has *no* entry here. Its widget
        # would be a permanent pill for a panel opened a few times a month, so
        # it is bound to mod+SHIFT+slash in hyprland/hyprland.lua instead
        # (`noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet`).
      };

      dock.enabled = false;
    };
  };
}
