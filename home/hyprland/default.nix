{
  pkgs,
  lib,
  theme,
  ...
}:
let
  # Bare hex: in the slurp wrapper's flags a leading '#' would start a comment.
  c = theme;
  # The same slots with '#', for the generated INI and CSS below.
  f = theme.fonts;

  # slurp in Ember for every caller (wl-ocr, the share picker's region button);
  # a caller's own flags still win.
  slurp = pkgs.symlinkJoin {
    name = "slurp-ember";
    paths = [ pkgs.slurp ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "slurp";
    postBuild = ''
      wrapProgram $out/bin/slurp --add-flags \
        "-b ${c.bgDeep}80 -c ${c.accent}ff -B ${c.accentDim}40"
    '';
  };

  # OCR a screen region and copy the text; the notification shows what was copied.
  ocrScript = pkgs.writeShellApplication {
    name = "wl-ocr";
    runtimeInputs = [
      slurp
      pkgs.grim
      pkgs.tesseract5
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = ''
      # slurp exits non-zero on Esc: leave the clipboard alone.
      region=$(slurp) || exit 0
      # $(...) drops tesseract's trailing newline.
      text=$(grim -g "$region" -t ppm - | tesseract - -)
      # Nothing recognised: keep the clipboard as it was.
      [[ $text == *[![:space:]]* ]] || exit 0
      printf '%s' "$text" | wl-copy
      notify-send -- "$text"
    '';
  };

  # Screen magnifier on cursor:zoom_factor, eased in short steps instead of one
  # jump. `hyprctl keyword` is a no-op under the Lua config, hence `hyprctl eval`.
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

  # Projector mirroring with Hyprland's native mirror, which letterboxes the
  # 16:10 panel on a 16:9 screen instead of stretching it. The rule goes in
  # through `hyprctl eval` and survives a reload via hyprland.lua's runtime-state
  # hooks. Fallback: `wl-mirror --fullscreen-output <output> -s fit eDP-1`.
  presentScript =
    let
      jq = lib.getExe pkgs.jq;
      notify = lib.getExe pkgs.libnotify;
    in
    pkgs.writeShellScriptBin "present" ''
      set -u
      builtin_panel="eDP-1"

      say() { echo "$1"; ${notify} -a present "Present" "$1"; }

      # A mirroring output is missing from the plain listing, so candidates are
      # the plain (live) outputs plus whatever `monitors all` shows mirroring.
      monitors=$(hyprctl monitors all -j) || { say "hyprctl unavailable"; exit 1; }
      live=$(hyprctl monitors -j) || { say "hyprctl unavailable"; exit 1; }

      # The one attached external display, or $2 when there are several:
      # mirroring the wrong one mid-talk is worse than refusing.
      target="''${2:-}"
      if [ -z "$target" ]; then
        candidates=$(${jq} -rn --arg b "$builtin_panel" \
          --argjson all "$monitors" --argjson live "$live" \
          '[$live[].name] + [$all[] | select(.mirrorOf != "none") | .name]
           | unique | .[] | select(. != $b)')
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

      # JSON mirrorOf is "none" or the source monitor's *id*, not its name, so
      # only the "none" test is meaningful.
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

      # A name-keyed rule outranks hyprland.lua's "" wildcard, so it restates
      # mode/position/scale (left off, scale falls back to "auto").
      hyprctl eval "hl.monitor({ output = \"$target\", mode = \"preferred\", position = \"auto\", scale = \"1\", mirror = \"$source\" })" >/dev/null

      if [ "$want" = mirror ]; then
        say "Mirroring $builtin_panel to $target"
      else
        say "Mirror off -- $target extended"
      fi
    '';
in
{
  imports = [
    ./theming.nix
    ./kanshi.nix
    ./wl-kbptr
    ./share-picker
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    # Explicit: with home.stateVersion < 26.05 the default is hyprlang.
    configType = "lua";
    extraConfig = builtins.readFile ./hyprland.lua;
    # Each `_var` becomes a Lua local ahead of extraConfig:
    # `local palette = { accent = "rgb(e08060)", ... }` and `fonts`.
    settings = {
      palette._var = lib.mapAttrs (_: hex: "rgb(${hex})") c.slots;
      fonts._var = { inherit (f) mono; };
    };
    plugins = [ pkgs.hy3 ];
    # On start the module exports the environment and restarts
    # hyprland-session.target. Stopping it also stops graphical-session.target
    # (PropagatesStopTo), so session daemons need WantedBy=graphical-session.target
    # to come back; a PartOf= unit started by hand stays down.
    systemd = {
      enable = true;
      variables = [ "--all" ];
      enableXdgAutostart = true;
    };
    xwayland.enable = true;
  };

  # Polkit auth prompts; the module's unit is WantedBy=graphical-session.target.
  services.hyprpolkitagent.enable = true;

  home.packages = with pkgs; [
    libnotify

    wdisplays # manage display positioning
    wl-clipboard
    wl-mirror

    ocrScript
    magnifyScript
    presentScript

    slurp # the palette-coloured wrapper from the let block

    wlrctl # clicks in hyprland.lua's mouse-cursor submap
  ];

  # wl-present (wl-mirror) needs a dmenu for `set-scaling` and `custom`, and none
  # of the ones it probes is installed; it calls `$DMENU -p "<prompt>"`.
  home.sessionVariables.WL_PRESENT_DMENU = "vicinae dmenu";

  # Lenovo's ICC profile for the panel (BOE NE160QAM-N62, P3-class), used by
  # hyprland.lua's eDP-1 rule; colord and other ICC-aware apps look here too.
  xdg.dataFile."icc/TPLCD_41BE_HDR.icm".source = ./icc/TPLCD_41BE_HDR.icm;
}
