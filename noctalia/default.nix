{
  inputs,
  pkgs,
  config,
  ...
}:
let
  p = import ../palette.nix;

  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Stormlight wording for noctalia's battery warnings (low at the threshold
  # and 5%, critical at 2%). `battery` is also the laptop's {device} label.
  stormlightStrings = pkgs.writeText "stormlight-strings.json" (builtins.toJSON {
    battery = "Stormlight";
    battery-low-title = "Stormlight running low";
    battery-low-body = "{device}: {percent}%. The spheres are going dun; set them out for the next highstorm.";
    battery-critical-title = "Life before death";
    battery-critical-body = "{device}: {percent}%. Your battery is dead. But I'll see what I can do.";
  });

  # noctalia's strings have no per-string override, so this is its asset
  # bundle as a symlink tree with en.json patched, used via
  # NOCTALIA_ASSETS_DIR. Fails the build if upstream renames a key.
  stormlightAssets =
    pkgs.runCommandLocal "noctalia-assets-stormlight" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        assets=${noctaliaPkg}/share/noctalia/assets
        cp -rs $assets $out
        chmod u+w $out/translations
        rm $out/translations/en.json
        jq --slurpfile s ${stormlightStrings} '
          (($s[0] | keys) - (.notifications.internal | keys)) as $missing
          | if $missing != [] then error("unknown keys: \($missing)") else . end
          | .notifications.internal += $s[0]
        ' $assets/translations/en.json > $out/translations/en.json
      '';

  # Step the volume of every output at once (speakers + each paired headset),
  # so the bar's volume pill changes what is actually playing rather than only
  # the currently-default sink. An output is an eq_* filter chain or a
  # hardware sink (one that carries a device.id). A hardware sink that an
  # eq_*_out stream plays into is skipped, so the step can't apply twice even
  # while pw-dump still lists it (pipewire-eq.nix's hide-parent normally hides
  # it from clients).
  #
  # `volume-all-sinks 5%+` / `5%-` steps them; `volume-all-sinks mute` toggles
  # them as one group (mute all unless every one is already muted, then unmute
  # all), so a headset and the speakers can never drift out of sync.
  #
  # It goes on PATH (home.packages below) because the hyprland volume binds
  # call it by name too: hyprland.lua is read verbatim, so it cannot carry a
  # store path. Both the bar gesture and the keys run this one script.
  volumeAllSinks = pkgs.writeShellApplication {
    name = "volume-all-sinks";
    runtimeInputs = [
      pkgs.wireplumber
      pkgs.pipewire
      pkgs.jq
    ];
    text = ''
      ids=$(pw-dump | jq -r '
        [.[] | select((.info.props."node.name" // "") | test("^eq_.*_out$"))
             | .info.props."target.object"] as $behindEq
        | .[]
        | select(.info.props."media.class" == "Audio/Sink")
        | select(.info.props."device.id" != null or (.info.props."node.name" | startswith("eq_")))
        | select(.info.props."node.name" | IN($behindEq[]) | not)
        | .id')
      case "$1" in
        mute)
          target=1
          for id in $ids; do
            [[ $(wpctl get-volume "$id") == *MUTED* ]] || { target=1; break; }
            target=0
          done
          for id in $ids; do wpctl set-mute "$id" "$target" || true; done
          ;;
        *)
          for id in $ids; do wpctl set-volume -l 1.0 "$id" "$1" || true; done
          ;;
      esac
    '';
  };

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
  # foreground on light. The rest of the ANSI block follows palette.nix's
  # `ansi` (kitty, ghostty).
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
in
{
  home.packages = [
    # Shared with the hyprland volume binds, see the definition above.
    volumeAllSinks
    # logcli for `dart logs` (the dart-plugin Logs button and terminal use).
    pkgs.grafana-loki

    # jrohland/claudecode gates its service on `commandExists("jq")`. jq was
    # only ever reachable as an interpolated store path (hyprland/default.nix),
    # never on PATH, so the plugin would have silently reported no data.
    pkgs.jq
  ];

  # dart-plugin: noctalia v5 Luau plugin showing DART training runs in the bar
  # (dart logo + running count; panel with per-run cancel/suspend/resume/delete).
  # Linked out-of-store so edits to ./dart-plugin hot-reload the running shell
  # (noctalia file-watches .luau files) without a rebuild. Swap to
  # `.source = ./dart-plugin;` for a pure store copy once it stabilises.
  # NOTE first switch: if `~/.local/share/noctalia/plugins/dart` already exists
  # from the pre-nix dev install, `rm` it first or activation fails.
  xdg.dataFile."noctalia/plugins/dart".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix_config/noctalia/dart-plugin";

  # Avatar read by shell.avatar_path below. The login screen can't reach it
  # (home is 0700); it gets the same image through AccountsService in
  # non_home_manager_config/noctalia-greeter.nix.
  home.file.".face".source = ../avatars/ratchet.png;

  systemd.user.services.noctalia.Service.Environment = [
    "NOCTALIA_ASSETS_DIR=${stormlightAssets}"
  ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;

    # Run noctalia as a systemd user service (restarts automatically on config changes)
    systemd.enable = true;

    # The Ember palette as a noctalia custom palette, written to
    # ~/.config/noctalia/palettes/Ember.json (the settings UI lists that
    # directory; `theme.custom_palette` below selects by file stem); a change
    # restarts noctalia. Generated from palette.nix so the shell can never
    # drift from the terminals.
    customPalettes.Ember = {
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

    # Declarative defaults for noctalia v5 (written to ~/.config/noctalia/config.toml).
    # Runtime tweaks via the settings UI still land in settings.toml and win over these.
    # Schema reference: example.toml in the noctalia repo.
    settings = {
      shell = {
        font_family = (import ../fonts.nix).ui;
        telemetry_enabled = false;
        avatar_path = "~/.face";
        # noctalia is the clipboard history (panel: mod+CONTROL+V in
        # hyprland.lua); vicinae's clipboard monitoring is switched off in
        # menu_launchers/ so the two don't both record every copy.
        clipboard_enabled = true;
        # Alt+Tab switcher lists windows most-recently-used first.
        window_switcher.mru = true;
        # Push wallpaper changes to Noctalia Greeter. Passwordless via the
        # Polkit rule from passwordlessSyncUsers in
        # non_home_manager_config/noctalia-greeter.nix; the greeter keeps its
        # own declared Ember palette.
        greeter_sync.auto_sync = true;

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
        # palette.nix by customPalettes above; it carries both halves, so
        # the control-center dark_mode toggle has a real light theme to switch
        # to instead of an auto-derived one.
        source = "custom";
        custom_palette = "Ember";
        # Propagate the palette to other apps' configs.
        templates = {
          # No "cava": cava isn't installed, and its template's apply.sh
          # exits 1 on every palette apply ("cava config file not found").
          # No "hyprland": its apply.sh appends a require to hyprland.lua,
          # a read-only store link, and fails on every start; hyprland.lua
          # keeps its own Ember colours.
          builtin_ids = [ ];
          community_ids = [ "telegram" ];
        };
      };

      # Used by nightlight sunset/sunrise scheduling (and weather widget).
      location.auto_locate = true;

      # Off, as last chosen in the control center.
      nightlight.enabled = false;

      weather = {
        enabled = true;
        unit = "celsius";
      };

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

      # noctalia owns the lockscreen, so the suspend interlock is stated here
      # rather than left to the default.
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
        { type = "dark_mode"; }
        { type = "noctalia/screen_recorder:toggle"; }
      ];

      # auto_update is plugins-wide. Off: it made the bar git-fetch both plugin
      # sources at every session start — network-dependent login latency that
      # stalled offline. Update deliberately from the plugin manager instead.
      # The local dani/* plugins are out-of-store symlinks and unaffected.
      plugins.auto_update = "none";
      # Plugins are opt-in per id even when present on disk. dani/dart is the
      # local dart run-manager plugin linked into ~/.local/share/noctalia/plugins
      # (see xdg.dataFile above). NB: `noctalia msg plugins enable/disable` and
      # the GUI write this same key into the runtime overrides file
      # (~/.local/state/noctalia/settings.toml), which replaces this array
      # wholesale — delete the [plugins] block there if this list stops applying.
      plugins.enabled = [
        "dani/dart"

        # Community plugins. The source clone is a `blob:none` partial clone and
        # noctalia's git calls do not lazy-fetch: if a newly enabled plugin shows
        # up empty, pre-warm its blobs with
        #   git -C ~/.local/state/noctalia/plugins/sources/community/repo \
        #     ls-tree -r HEAD -- <dir> | awk '{print $3}' | git -C ... cat-file --batch-check
        # before enabling. Same trap makes the whole community catalog vanish
        # from the list after a bare `git fetch` until catalog.toml is fetched.

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

        # gpu-screen-recorder front end (official source). Deliberately no bar
        # widget: its headless service runs regardless, Super+Shift+R drives it
        # over IPC (hyprland.lua) and the control-center tile below mirrors it.
        # gpu-screen-recorder comes from programs.gpu-screen-recorder in
        # configuration.nix.
        "noctalia/screen_recorder"
      ];

      # Super+Shift+R leaves the saved recording on the clipboard as a file://
      # URI (text/uri-list), so it pastes into apps as the file itself; a
      # terminal won't paste it. Plugin-wide, so the control-center tile too.
      plugin_settings."noctalia/screen_recorder".copy_to_clipboard = true;

      wallpaper = {
        enabled = true;
        directory = "~/nix_config/wallpapers";
        fill_mode = "crop";
      };

      notification = {
        enable_daemon = true;
        # Silence every notification without touching the other UI sounds
        # (volume click, screenshot, plug/unplug) that audio.enable_sounds
        # would also kill. Filters are first-match; "^" is a regex that
        # matches any summary/body, so this one catches everything. Any
        # per-app filter added later must sort before it to take effect.
        filter.silent = {
          match_content = "^";
          play_sound = false;
        };
      };

      # First low-battery warning; noctalia adds fixed 5% and 2% levels.
      battery.warning_threshold = 20;

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

        # Plain lanes: every widget draws its own pill. The grouped
        # three-island version was tried and rejected (2026-09-16) — dart
        # belongs next to the workspaces, and the right side reads better as
        # separate pills. The one exception is the cpu/ram sysmon group
        # below (2026-09-22): those two belong together as one meter.
        #
        # Semantic grouping (2026-09-22): the clock+weather pill leads the bar
        # since time/date is the thing you glance at first. Right side leads
        # with the tray pill (tray, notifications), then the
        # bluetooth/volume/brightness pill, and the machine-state pill (cpu,
        # ram, gpu, battery) anchors the far right edge. claudecode usage sits
        # in the center, left of the workspaces (2026-09-28).
        start = [
          "group:clockweather"
          "active_window"
          "media"
        ];
        center = [
          "privacy"
          "claudecode"
          "workspaces"
          "dart"
        ];
        end = [
          "group:tray"
          "group:volbright"
          "group:sysmon"
        ];

        capsule_group = [
          # clock + weather share one pill.
          {
            id = "clockweather";
            members = [
              "clock"
              "weather"
            ];
            fill = "surface_variant";
          }
          # tray + notifications share one pill.
          {
            id = "tray";
            members = [
              "tray"
              "notifications"
            ];
            fill = "surface_variant";
          }
          # bluetooth + volume + brightness share one pill.
          {
            id = "volbright";
            members = [
              "bluetooth"
              "volume"
              "brightness"
            ];
            fill = "surface_variant";
          }
          # cpu + ram + gpu + vram + battery share one machine-state pill.
          {
            id = "sysmon";
            members = [
              "sysmon"
              "ram"
              "gpu"
              "vram"
              "battery"
            ];
            fill = "surface_variant";
          }
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

        # Never set `anchor` on the clock (the settings GUI can save it to
        # settings.toml): bar.cpp won't merge an anchored widget into a
        # capsule_group, so it silently splits off the clockweather pill.
        clock = {
          format = "{:%H:%M %a, %b %d}";
          tooltip_format = "{:%A, %B %d, %Y}";
        };

        # Current conditions, sourced from [weather] above (coordinates
        # resolved from the location block).
        weather = {
          show_temperature = true;
          show_condition = true;
        };

        # Scrolling the pill steps every hardware sink (see volumeAllSinks),
        # not just the default one; the label and left/right click still
        # follow the default sink.
        volume = {
          actions.scroll_up = "exec ${volumeAllSinks}/bin/volume-all-sinks 5%+";
          actions.scroll_down = "exec ${volumeAllSinks}/bin/volume-all-sinks 5%-";
        };

        # CPU utilisation gauge (default sysmon stat is cpu_usage).
        sysmon = {
          stat = "cpu_usage";
        };

        # RAM used %, alongside the cpu sysmon pill.
        ram = {
          type = "sysmon";
          stat = "ram_pct";
        };

        # dGPU utilisation and VRAM, read over NVML from the RTX 5090 (the
        # i915 iGPU exposes neither). Mostly for ollama and DART runs: a model
        # that spilled to CPU shows up as low VRAM. The VRAM gauge idles at
        # ~2%, the driver's reserved memory, which nvidia-smi lists apart from
        # "Used". Polling costs no D3 sleep: Hyprland holds /dev/nvidia0 open,
        # so the card stays in D0 regardless. Own glyphs (cube, stack) so they
        # don't reuse the cpu/ram ones: the defaults gave vram the same chip
        # icon as ram.
        gpu = {
          type = "sysmon";
          stat = "gpu_usage";
          glyph = "cube";
        };
        vram = {
          type = "sysmon";
          stat = "gpu_vram";
          glyph = "stack-2";
        };

        # Icon + connected device name in the bar; hovering lists each
        # connected device with its battery %. Left-click opens the
        # control-center bluetooth tab, right-click toggles bluetooth power.
        bluetooth = {
          show_label = true;
          hide_when_no_connected_device = false;
        };

        tray = {
          hide_passive = true;
          drawer = true;
          # The list last saved from the settings GUI.
          pinned = [
            "Fcitx"
            "Slack_status_icon_1"
            "Element_status_icon_1"
            "org.twosheds.iwgtk"
          ];
        };

        # Mic / camera / screen-share indicator: the screen recorder and xdph
        # screencasts capture without any other visible sign. Hidden while
        # nothing is capturing.
        privacy = {
          hide_inactive = true;
        };

        # DART run manager (local Luau plugin, see dart-plugin/). Same alias
        # idiom as the custom_buttons above: bare "dart" in the bar list
        # resolves through this table to the plugin widget entry.
        dart = {
          type = "dani/dart:widget";
        };

        # Claude Code subscription usage (jrohland/claudecode). Stays blank
        # until jq is on the shell's PATH — see the home.packages note above.
        claudecode = {
          type = "jrohland/claudecode:pill";
        };
      };

      dock.enabled = false;
    };
  };
}
