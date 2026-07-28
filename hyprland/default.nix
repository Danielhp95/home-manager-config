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
in
{
  imports = [ ./theming.nix ];
  programs.hyprlock = {
    enable = true;
    extraConfig = builtins.readFile ./hyprlock.conf;
  };
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
    systemd = {
      enable = true;
      variables = [ "--all" ];
      extraCommands = [
        "systemctl --user start hyprpolkitagent"
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
    xwayland.enable = true;
  };
  home.packages = with pkgs; [
    hyprpolkitagent # Authenticator

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

    # This should really live on its own package
    slurp
    wf-recorder

    wl-kbptr # Mouse control with keyboard in wayland
    wlrctl # Command line utility for miscellaneous wlroots Wayland extensions
  ];

  # Battery notifications
  xdg.configFile."wl-kbptr.yaml".source = ./wl-kbptr.yaml;
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = hyprland-preview-share-picker
      allow_token_by_default = true
    }
  '';
  services.batsignal = {
    # TODO: This is not working
    enable = true;
    extraArgs = [
      "-d 5"
      "-c 10"
      "-w 30"
      "-f 97"
      "-D ${pkgs.systemd}/bin/systemctl suspend" # Suspend at danger level
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
