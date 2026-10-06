{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  p = import ../palette;
  material = import ./material.nix { inherit lib; };
  # A palette's file stem under ~/.config/noctalia/palettes, which is also the
  # name the settings GUI shows and `theme.custom_palette` selects.
  stem = palette: builtins.replaceStrings [ " " ] [ "" ] palette.meta.name;

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

  # Steps every output at once (eq_* chains and hardware sinks), not just the
  # default sink; a hardware sink an eq_*_out stream plays into is skipped so
  # nothing steps twice. `mute` toggles them all as one group. On PATH because
  # hyprland.lua (read verbatim) calls it by name.
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
in
{
  home.packages = [
    volumeAllSinks
    # logcli, for `dart logs` (the dart plugin's Logs button).
    pkgs.grafana-loki
    # jrohland/claudecode only runs with jq on PATH (commandExists("jq")).
    pkgs.jq
    # rylos/tailnet asks `xdg-user-dir DOWNLOAD` for its Taildrop directory.
    pkgs.xdg-user-dirs
  ];

  # The local DART plugin, linked out of the store so edits to ./dart-plugin
  # hot-reload in the running shell without a rebuild.
  xdg.dataFile."noctalia/plugins/dart".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix_config/noctalia/dart-plugin";

  # For shell.avatar_path. The greeter can't read ~ (0700) and gets the same
  # image through AccountsService (non_home_manager_config/noctalia-greeter.nix).
  home.file.".face".source = import ../avatars { inherit pkgs; };

  systemd.user.services.noctalia.Service.Environment = [
    "NOCTALIA_ASSETS_DIR=${stormlightAssets}"
  ];

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
        font_family = (import ../fonts.nix).ui;
        telemetry_enabled = false;
        avatar_path = "~/.face";
        # The clipboard history (mod+CONTROL+V); vicinae's is off in
        # menu_launchers/ so copies aren't recorded twice.
        clipboard_enabled = true;
        window_switcher.mru = true;
        # Push wallpaper changes to the greeter; passwordless via the Polkit
        # rule in non_home_manager_config/noctalia-greeter.nix.
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

      # No git fetch of the plugin sources at every login (it stalled offline);
      # update from the plugin manager instead.
      plugins.auto_update = "none";
      # Opt-in per id. `noctalia msg plugins enable/disable` and the GUI write
      # this key into settings.toml, which then replaces this whole list:
      # delete the [plugins] block there if this stops applying.
      plugins.enabled = [
        "dani/dart"

        # Community plugins come from a blob:none clone that noctalia never
        # lazy-fetches: after a bare `git fetch` the catalog comes up empty, and
        # a newly enabled plugin can too. Update with `noctalia msg plugins
        # update`, or pre-warm the plugin's blobs (git cat-file --batch-check).

        # Claude Code subscription usage; needs jq and curl on PATH.
        "jrohland/claudecode"

        # Keybinds read from the running compositor via hyprctl; plugins that
        # parse hyprland.conf can't read the lua config.
        "kenn/keybind-cheatsheet"

        # Tailscale state, peers (copy IP/name), exit nodes; also a `tn`
        # launcher prefix. Needs tailscale and ssh from the system profile.
        "rylos/tailnet"

        # gpu-screen-recorder front end, no bar widget: Super+Shift+R
        # (hyprland.lua) and the control-center tile drive it.
        "noctalia/screen_recorder"
      ];

      # The recording lands on the clipboard as a file:// URI, which pastes as
      # the file into apps (not into terminals).
      plugin_settings."noctalia/screen_recorder".copy_to_clipboard = true;

      wallpaper = {
        enabled = true;
        directory = "~/nix_config/wallpapers";
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

      # First low-battery warning; noctalia adds fixed 5% and 2% levels.
      battery.warning_threshold = 20;

      # Floating pills: a transparent bar (its shadow scales with
      # background_opacity, so it has none) with every widget in its own
      # capsule. Must be named "default" to replace the built-in bar; any other
      # name adds a second one.
      bar.default = {
        position = "top";
        thickness = 36;
        background_opacity = 0.0;
        # No protocol blur behind the bar: the pills are opaque, and the gaps
        # between them stay clear. noctalia asks the compositor to blur the
        # whole bar rect (ext-background-effect-v1), which Hyprland's layer
        # rules can't switch off; this drops the request itself (5.2.1).
        # https://docs.noctalia.dev/noctalia/bar/ ("compositor_blur")
        compositor_blur = false;
        radius = 18;
        margin_ends = 8; # inset from each end of the bar
        # margin_edge: gap above; margin_opposite_edge: gap below, taken from
        # the reserved space. 6/0 sat a pixel low.
        margin_edge = 5;
        margin_opposite_edge = 1;
        padding = 12;
        widget_spacing = 8;
        shadow = true;
        capsule = true;
        capsule_fill = "surface_variant";
        capsule_opacity = 1.0;
        # Fraction of bar thickness (default 0.76); the pills are the whole bar.
        capsule_thickness = 0.88;

        # One pill per widget, except the capsule_groups below.
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
          {
            id = "clockweather";
            members = [
              "clock"
              "weather"
            ];
            fill = "surface_variant";
          }
          {
            id = "tray";
            members = [
              "tray"
              "tailnet"
              "notifications"
            ];
            fill = "surface_variant";
          }
          {
            id = "volbright";
            members = [
              "bluetooth"
              "volume"
              "brightness"
            ];
            fill = "surface_variant";
          }
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

      # eDP-1 is intel_backlight; pin the sysfs backend so noctalia never falls
      # back to ddc/none.
      brightness = {
        monitor."eDP-1".backend = "backlight";
      };

      widget = {
        # Names (nerdfont glyphs, set in hyprland.lua) instead of numbers.
        workspaces = {
          label_source = "name";
          show_labels = true;
          # Other monitors' active workspaces fall back to occupied_color.
          focused_output_only = true;
        };

        # Never set `anchor` here (the settings GUI can save one): an anchored
        # widget splits off the clockweather pill.
        clock = {
          format = "{:%H:%M %a, %b %d}";
          tooltip_format = "{:%A, %B %d, %Y}";
        };

        weather = {
          show_temperature = true;
          show_condition = true;
        };

        # Scrolling steps every output (volumeAllSinks); the label and clicks
        # still follow the default sink.
        volume = {
          actions.scroll_up = "exec ${volumeAllSinks}/bin/volume-all-sinks 5%+";
          actions.scroll_down = "exec ${volumeAllSinks}/bin/volume-all-sinks 5%-";
        };

        sysmon = {
          stat = "cpu_usage";
        };

        ram = {
          type = "sysmon";
          stat = "ram_pct";
        };

        # dGPU load and VRAM over NVML (the iGPU exposes neither); VRAM idles
        # at ~2%, the driver's reserve. Polling costs no D3 sleep: Hyprland
        # holds /dev/nvidia0 open anyway. Own glyphs: the default vram icon is
        # ram's.
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

        bluetooth = {
          show_label = true;
          hide_when_no_connected_device = false;
        };

        tray = {
          hide_passive = true;
          drawer = true;
          pinned = [
            "Fcitx"
            "Slack_status_icon_1"
            "Element_status_icon_1"
            "org.twosheds.iwgtk"
          ];
        };

        # Mic / camera / screencast indicator; the screen recorder and xdph
        # screencasts show no other sign.
        privacy = {
          hide_inactive = true;
        };

        # Aliases: bare "dart" / "claudecode" in the bar lanes resolve through
        # these to the plugins' widget entries.
        dart = {
          type = "dani/dart:widget";
        };

        claudecode = {
          type = "jrohland/claudecode:pill";
        };

        tailnet = {
          type = "rylos/tailnet:bar";
        };
      };

      dock.enabled = false;
    };
  };
}
