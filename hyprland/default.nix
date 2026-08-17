{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # use OCR and copy to clipboard
  ocrScript =
    let
      inherit (pkgs)
        grim
        libnotify
        slurp
        tesseract5
        wl-clipboard
        ;
      _ = lib.getExe;
    in
    pkgs.writeShellScriptBin "wl-ocr" ''
      ${_ grim} -g "$(${_ slurp})" -t ppm - | ${_ tesseract5} - - | ${wl-clipboard}/bin/wl-copy
      ${_ libnotify} "$(${wl-clipboard}/bin/wl-paste)"
    '';

  # Toggle whether Hyprland opens the NVIDIA dGPU on its next start (marker
  # file read by hyprland.lua). "on" enables the HDMI port (dGPU stays awake,
  # ~8W); "off" lets the dGPU runtime-suspend for battery life. Note: CUDA /
  # `nvidia-offload <game>` work in EITHER mode — the GPU wakes on demand for
  # compute/offload; this toggle only matters for driving displays over HDMI.
  dgpuScript = pkgs.writeShellScriptBin "dgpu" ''
    marker="$HOME/.config/hypr/dgpu-mode"
    notify=${lib.getExe pkgs.libnotify}
    case "''${1:-status}" in
      on)
        mkdir -p "$(dirname "$marker")" && touch "$marker"
        msg="dGPU mode ON pending — log out/in to enable the HDMI port"
        echo "$msg"; $notify -a dgpu "dGPU" "$msg"
        ;;
      off)
        rm -f "$marker"
        msg="dGPU mode OFF pending — log out/in to let the GPU sleep"
        echo "$msg"; $notify -a dgpu "dGPU" "$msg"
        ;;
      toggle)
        if [ -e "$marker" ]; then exec "$0" off; else exec "$0" on; fi
        ;;
      status)
        [ -e "$marker" ] && echo "next session: dGPU ON (HDMI enabled)" \
                         || echo "next session: dGPU OFF (battery mode)"
        rt=$(cat /sys/bus/pci/devices/0000:02:00.0/power/runtime_status 2>/dev/null)
        echo "right now: GPU is ''${rt:-unknown}"
        ;;
      *)
        echo "usage: dgpu [on|off|toggle|status]" >&2; exit 1
        ;;
    esac
  '';

  # Screen magnifier — replaces pyprland's `magnify` plugin, which was only ever
  # a wrapper around Hyprland's native cursor:zoom_factor. Animates the zoom in
  # short eased steps so it doesn't snap the way a single jump would.
  # NOTE: under configType = "lua" (Hyprland >= 0.55) `hyprctl keyword` answers
  # "unknown request" — live config changes go through `hyprctl eval` instead.
  magnifyScript = pkgs.writeShellScriptBin "magnify" ''
    awk=${lib.getExe pkgs.gawk}
    steps=10
    frame=0.008
    default=2.0   # zoom level a bare `magnify` toggles to
    max=10.0

    cur=$(hyprctl getoption cursor:zoom_factor | $awk '/^float/{print $2}')
    [ -n "$cur" ] || cur=1.0

    case "''${1:-toggle}" in
      toggle)
        # zooming out forgets the level we were at: the next toggle always comes
        # back at $default rather than however far the +/- binds had crept up
        if $awk -v c="$cur" 'BEGIN{exit !(c > 1.01)}'; then
          target=1.0
        else
          target="$default"
        fi
        ;;
      reset) target=1.0 ;;
      status) echo "$cur"; exit 0 ;;
      +*|-*) target=$($awk -v c="$cur" -v d="''${1}" 'BEGIN{print c + d}') ;;
      *)
        case "$1" in
          *[!0-9.]*|"") echo "usage: magnify [toggle|reset|status|+N|-N|<factor>]" >&2; exit 1 ;;
        esac
        target="$1"
        ;;
    esac

    # cursor:zoom_factor < 1.0 is invalid; clamp both ends
    target=$($awk -v t="$target" -v m="$max" 'BEGIN{if(t<1)t=1; if(t>m)t=m; printf "%.3f", t}')

    # all frames from one awk (eased out); a subshell per frame made the
    # animation visibly laggy when a +/- bind is held down
    $awk -v c="$cur" -v t="$target" -v n="$steps" \
      'BEGIN{for(i=1;i<=n;i++){p=i/n; e=1-(1-p)*(1-p); printf "%.3f\n", c+(t-c)*e}}' |
    while read -r v; do
      hyprctl eval "hl.config({ cursor = { zoom_factor = $v } })" >/dev/null
      sleep $frame
    done
  '';

  # Projector mirroring. Hyprland's native mirror is the right tool here: its
  # renderMirrored() scales by min(dstW/srcW, dstH/srcH) and centres, so a 16:10
  # laptop on a 16:9 projector comes out pillarboxed rather than stretched or
  # cropped (1920x1200 -> 1728x1080 with 96px bars either side).
  #
  # Two Hyprland quirks make this a two-step: `hyprctl keyword` is a no-op under
  # configType = "lua" (use `hyprctl eval` instead, as magnify does above), AND
  # eval alone only *registers* the monitor rule -- unlike hl.config values,
  # which are read live each frame, monitor rules need an explicit re-apply.
  # `dispatch forcerendererreload` re-fetches every monitor's rule and applies it.
  #
  # The rule this registers lives only in the running Hyprland: any config reload
  # (`hyprctl reload`, or a home-manager switch) re-reads hyprland.lua and drops
  # it, so mirroring silently reverts to extended. Fine as a default -- just don't
  # rebuild mid-presentation, and re-run `present on` if you do.
  #
  # Escape hatch if that ever breaks: `wl-mirror --fullscreen-output DP-2 -s fit
  # eDP-1` does the same letterboxed mirror out-of-process (wl-mirror is already
  # in home.packages, and `wl-present` wraps it in a rofi menu).
  presentScript =
    let
      jq = lib.getExe pkgs.jq;
      notify = lib.getExe pkgs.libnotify;
    in
    pkgs.writeShellScriptBin "present" ''
      set -u
      builtin_panel="eDP-1"

      say() { echo "$1"; ${notify} -a present "Present" "$1"; }

      # `monitors all`, not `monitors`: a monitor that is currently mirroring is
      # omitted from the plain listing entirely, so the plain one can see how to
      # turn mirroring on but never how to turn it back off. `all` also includes
      # disabled outputs, hence the .disabled filter below.
      monitors=$(hyprctl monitors all -j) || { say "hyprctl unavailable"; exit 1; }

      # The target is whatever external display is attached. Named explicitly as
      # $2 when more than one is (at the desk both HPs are), since mirroring the
      # wrong panel mid-talk is worse than refusing.
      target="''${2:-}"
      if [ -z "$target" ]; then
        candidates=$(printf '%s' "$monitors" | ${jq} -r --arg b "$builtin_panel" \
          '.[] | select(.name != $b and .disabled == false) | .name')
        count=$(printf '%s' "$candidates" | grep -c . || true)
        case "$count" in
          0) say "No external display connected"; exit 1 ;;
          1) target="$candidates" ;;
          *) say "Several external displays -- pick one: $(echo "$candidates" | tr '\n' ' ')"; exit 1 ;;
        esac
      fi

      mirror_of=$(printf '%s' "$monitors" | ${jq} -r --arg t "$target" \
        '.[] | select(.name == $t) | .mirrorOf')
      [ -n "$mirror_of" ] || { say "No such display: $target"; exit 1; }

      # In the JSON, mirrorOf is the literal string "none" when the output stands
      # alone, and the *id* of the source monitor (e.g. "0") when it is mirroring
      # -- not the name the text output shows. Only the "none" test is meaningful.
      case "''${1:-toggle}" in
        on)     want=mirror ;;
        off)    want=extend ;;
        toggle) [ "$mirror_of" = "none" ] && want=mirror || want=extend ;;
        status)
          if [ "$mirror_of" = "none" ]; then
            echo "$target: extended"
          else
            src=$(printf '%s' "$monitors" | ${jq} -r --arg m "$mirror_of" \
              '.[] | select((.id | tostring) == $m) | .name')
            echo "$target: mirroring ''${src:-monitor $mirror_of}"
          fi
          exit 0
          ;;
        *) echo "usage: present [toggle|on|off|status] [output]" >&2; exit 1 ;;
      esac

      if [ "$want" = mirror ]; then
        source="$builtin_panel"
      else
        source=""  # empty string is how setMirror() is told to unmirror
      fi

      # mode/position/scale are restated because this creates a rule keyed on the
      # output name, which outranks the "" wildcard in hyprland.lua -- leaving them
      # off would silently fall back to the binding's own defaults (scale "auto").
      hyprctl eval "hl.monitor({ output = \"$target\", mode = \"preferred\", position = \"auto\", scale = \"1\", mirror = \"$source\" })" >/dev/null
      hyprctl dispatch forcerendererreload >/dev/null

      if [ "$want" = mirror ]; then
        say "Mirroring $builtin_panel to $target"
      else
        say "Mirror off -- $target extended"
      fi
    '';
in
{
  imports = [ ./theming.nix ];
  # NOTE: hyprlock is gone (and ./hyprlock.conf with it). noctalia's lockscreen
  # is the only one now — it is what the lid switch and the lock keybind in
  # hyprland.lua call, what noctalia's idle behaviours raise (noctalia/
  # default.nix), and what suspend locks behind. Having both meant two
  # lockscreens with two themes reachable by two different paths.
  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland >= 0.55 / nixpkgs 26.05 default: config is written in lua.
    # hy3 (hl0.55+) exposes its dispatchers under hl.plugin.hy3 in lua.
    configType = "lua";
    extraConfig = builtins.readFile ./hyprland.lua;
    plugins = with pkgs; [
      hy3
    ];
    # NOTE: the dbus-update-activation-environment exec-once entries that used to
    # live here are now in hyprland.lua's hl.on("hyprland.start", ...) hook, since
    # `settings` is serialized as hl.<name>(...) lua calls under configType = "lua".
    # UWSM owns the session lifecycle now (tuigreet launches `uwsm start`,
    # see tuigreet.nix): it exports the env to the user manager and manages
    # graphical-session.target canonically, so the old stop/start dance (and
    # its PartOf= footguns) is gone. Hyprland reports back via `uwsm finalize`
    # in hyprland.lua's start hook.
    systemd.enable = false;
    xwayland.enable = true;
  };

  # Polkit auth prompts. The module's WantedBy=graphical-session.target wants-symlink
  # survives the stop/start dance in extraCommands above; a manual `systemctl start`
  # here would be killed by the target stop (PartOf= propagation).
  services.hyprpolkitagent.enable = true;

  home.packages = with pkgs; [
    inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default # cooler screen picker

    # For screenshots
    hyprshot
    satty

    pw-volume

    hyprpicker

    libnotify

    wdisplays # manage display positioning
    wl-clipboard # wayland clipboard utilities
    wl-mirror # For mirroring screens

    ocrScript
    dgpuScript
    magnifyScript
    presentScript

    # This should really live on its own package
    slurp
    # wf-recorder

    wl-kbptr # Mouse control with keyboard in wayland
    wlrctl # Command line utility for miscellaneous wlroots Wayland extensions
  ];

  # wl-present (in the wl-mirror package above) shells out to a dmenu for its
  # `set-scaling` and `custom` subcommands, auto-detecting wofi/wmenu/fuzzel/
  # rofi/dmenu in that order — none of which are installed since rofi went away,
  # so it would have fallen through to a bare `dmenu` that does not exist. It
  # calls `$DMENU -p "<prompt>"`, which is exactly vicinae's dmenu interface.
  # Only reaches things launched from a shell; the `present` script above and
  # plain `wl-mirror` need no picker either way.
  home.sessionVariables.WL_PRESENT_DMENU = "vicinae dmenu";

  # Battery notifications
  xdg.configFile."wl-kbptr.yaml".source = ./wl-kbptr.yaml;
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = hyprland-preview-share-picker
      allow_token_by_default = true
    }
  '';
  services.batsignal = {
    enable = true;
    # Each list element becomes one argv entry, so a flag and its value have to
    # be separate strings. "-d 5" survived only because atoi() skips the leading
    # space; "-n BAT0" would not — batsignal looks for a battery literally named
    # " BAT0" and exits 1.
    extraArgs = [
      # Without -n, batsignal watches every /sys/class/power_supply entry —
      # including the DualShock's `ps-controller-battery-*`, which exposes no
      # charge_now. That read fails, batsignal exits 1, and systemd
      # restart-loops it until the start limit: ~1.2s of every login, and no
      # battery notifications at all (the old "this is not working" TODO).
      "-n" "BAT0"
      "-d" "5"
      "-c" "10"
      "-w" "30"
      "-f" "97"
      "-D" "${pkgs.systemd}/bin/systemctl suspend" # Suspend at danger level
      # "-C" "Running out of Stormlight"
      # "-W" "Draining Stormlight at an alarming rate"
      # "-F" "Stormlight reserves full"
      # "-e" # Cause notifications to expire
      # "-p -P Charging Stormlight"
      # "-U Discharging Stormlight"
      # "-i" # Ignore missing battery notifications, for desktops
      # "-I 🔋" # Icon
    ];
  };
}
