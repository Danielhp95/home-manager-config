{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Bare hex: in the slurp wrapper's flags a leading '#' would start a comment.
  c = import ../palette.nix;
  f = import ../fonts.nix;

  # slurp in Ember, wrapped so every caller gets it (wl-ocr, the share
  # picker's region button, ad-hoc use). A caller's own flags still win.
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

  # use OCR and copy to clipboard
  ocrScript =
    let
      inherit (pkgs)
        grim
        libnotify
        tesseract5
        wl-clipboard
        ;
      _ = lib.getExe;
    in
    pkgs.writeShellScriptBin "wl-ocr" ''
      ${_ grim} -g "$(${_ slurp})" -t ppm - | ${_ tesseract5} - - | ${wl-clipboard}/bin/wl-copy
      ${_ libnotify} "$(${wl-clipboard}/bin/wl-paste)"
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
      # turn mirroring on but never how to turn it back off.
      #
      # `all` also lists disabled outputs, but its JSON `disabled` field can't
      # weed them out: Hyprland 0.56 serialises it as m_enabled (the text output
      # correctly uses !m_enabled; see src/ipc/s1/Commands.cpp), so every live
      # monitor reads `disabled: true`. Filtering on it left no candidates and
      # `present` always said "No external display connected". Instead, "live"
      # is taken from the plain listing, which only holds enabled, unmirrored
      # monitors, plus whatever `all` shows as mirroring. That never touches the
      # field, so it survives upstream fixing it.
      monitors=$(hyprctl monitors all -j) || { say "hyprctl unavailable"; exit 1; }
      live=$(hyprctl monitors -j) || { say "hyprctl unavailable"; exit 1; }

      # The target is whatever external display is attached. Named explicitly as
      # $2 when more than one is, since mirroring the
      # wrong panel mid-talk is worse than refusing.
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
  imports = [
    ./theming.nix
    ./kanshi.nix
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland >= 0.55 / nixpkgs 26.05 default: config is written in lua.
    # hy3 (hl0.55+) exposes its dispatchers under hl.plugin.hy3 in lua.
    configType = "lua";
    extraConfig = builtins.readFile ./hyprland.lua;
    plugins = with pkgs; [
      hy3
    ];
    # greetd launches the compositor via `start-hyprland` (Hyprland's own
    # crash-watchdog binary, see non_home_manager_config/noctalia-greeter.nix)
    # instead of uwsm now. Session lifecycle is back on this module's own
    # systemd integration: on hyprland.start it runs
    # `dbus-update-activation-environment --systemd` then the *default*
    # extraCommands (stop/start hyprland-session.target,
    # which activates graphical-session.target). Do NOT override extraCommands
    # to stop graphical-session.target directly — that was the old hand-rolled
    # hook and it silently killed hyprpolkitagent/gpg-agent.socket every login
    # (see graphical-session-target-dance memory): stopping
    # graphical-session.target tears down every PartOf= unit, and only
    # WantedBy= units come back when hyprland-session.target pulls the target
    # back up. The module's default (stop/start hyprland-session.target, one
    # level down) avoids that.
    systemd = {
      enable = true;
      variables = [ "--all" ];
      enableXdgAutostart = true;
    };
    xwayland.enable = true;
  };

  # Polkit auth prompts. The module's WantedBy=graphical-session.target wants-symlink
  # survives the stop/start dance in extraCommands above; a manual `systemctl start`
  # here would be killed by the target stop (PartOf= propagation).
  services.hyprpolkitagent.enable = true;

  home.packages = with pkgs; [
    # Cooler screen picker (window/monitor previews instead of a bare list).
    #
    # The Outputs tab drops every monitor unpatched: the picker enumerates
    # wl_outputs, then looks each name up in `hyprctl monitors`, having first
    # filtered that list by `!disabled`. Hyprland serialises that field as
    # `!m_enabled`, and since the 0.56 rev pinned below it reports `disabled:
    # true` for monitors that are plainly enabled and rendering (the Lua API
    # disagrees with itself here — `hl.get_monitors()[i].enabled` is true for
    # the same monitors). So the filter empties the list, every wl_output then
    # misses its lookup, and the tab renders with nothing in it — "output
    # <name> does not exist on hyprland" in /tmp/hyprland-preview-share-picker.log.
    #
    # Dropping the filter is safe: `hyprctl monitors` without `all` only lists
    # live monitors to begin with, so it was never load-bearing here.
    # Upstream bug: WhySoBad/hyprland-preview-share-picker#28. Drop this when
    # either side fixes it — the substituteInPlace is --replace-fail, so a
    # picker bump that touches the line fails the build rather than silently
    # going back to an empty tab.
    (inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/views/outputs.rs \
          --replace-fail '.map(|monitors| monitors.into_iter().filter(|monitor| !monitor.disabled).collect::<Vec<_>>())' \
                         '.map(|monitors| monitors.into_iter().collect::<Vec<_>>())'
      '';
    }))

    # Screenshots and annotation are noctalia's (noctalia/default.nix).

    # Volume keys use `volume-all-sinks` from noctalia/default.nix.

    hyprpicker

    libnotify

    wdisplays # manage display positioning
    wl-clipboard # wayland clipboard utilities
    wl-mirror # For mirroring screens

    ocrScript
    magnifyScript
    presentScript

    # This should really live on its own package
    slurp # Ember wrapper from the let block
    # wf-recorder

    wl-kbptr # Mouse control with keyboard in wayland
    wlrctl # Command line utility for miscellaneous wlroots Wayland extensions
  ];

  # wl-present (in the wl-mirror package above) shells out to a dmenu for its
  # `set-scaling` and `custom` subcommands, auto-detecting wofi/wmenu/fuzzel/
  # rofi/dmenu in that order — none of which are installed, so it would fall
  # through to a bare `dmenu` that does not exist. It
  # calls `$DMENU -p "<prompt>"`, which is exactly vicinae's dmenu interface.
  # Only reaches things launched from a shell; the `present` script above and
  # plain `wl-mirror` need no picker either way.
  home.sessionVariables.WL_PRESENT_DMENU = "vicinae dmenu";

  # Lenovo's profile for the T16g's panel (BOE NE160QAM-N62, P3-class, 800
  # nit), from Lenovo's ICC package. A matrix profile: the panel's EDID
  # primaries, D65, gamma 2.19, no VCGT. hyprland.lua points the eDP-1 rule at
  # it; ~/.local/share/icc is where colord and other ICC-aware apps look too.
  xdg.dataFile."icc/TPLCD_41BE_HDR.icm".source = ./icc/TPLCD_41BE_HDR.icm;

  # INI despite the name; hyprland.lua passes it with --config. Unset keys
  # take wl-kbptr's defaults.
  xdg.configFile."wl-kbptr.yaml".text = ''
    [general]
    modes=floating,click

    [mode_tile]
    label_color=#${c.fg}
    label_select_color=#${c.gold}
    unselectable_bg_color=#${c.bgDeep}66
    selectable_bg_color=#${c.ash}
    selectable_border_color=#${c.fgDim}

    [mode_floating]
    source=detect
    label_color=#${c.fg}
    label_select_color=#${c.gold}
    unselectable_bg_color=#${c.bgDeep}66
    selectable_bg_color=#${c.ash}
    selectable_border_color=#${c.fgDim}
    label_font_family=${f.monoSemiBold}
    label_font_size=16 80% 100

    [mode_bisect]
    label_color=#${c.fg}
    pointer_color=#${c.accent}
    unselectable_bg_color=#${c.bgDeep}
    even_area_bg_color=#${c.ash}
    even_area_border_color=#${c.fgDim}
    odd_area_bg_color=#${c.muted}
    odd_area_border_color=#${c.fgSoft}
    history_border_color=#${c.gold}

    [mode_split]
    pointer_color=#${c.accent}
    bg_color=#${c.bgDeep}
    area_bg_color=#${c.ash}
    vertical_color=#${c.muted}
    horizontal_color=#${c.fgDim}
    history_border_color=#${c.gold}

    [mode_click]
    button=left
  '';
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = hyprland-preview-share-picker
      allow_token_by_default = true
    }
  '';
  # Colours only, over WhiteSur's GTK4 widgets. `.window > box` is needed
  # because the picker's css_classes() drops GTK's `background` class.
  xdg.configFile."hyprland-preview-share-picker/config.yaml".text = ''
    stylesheets: [ember.css]
  '';
  xdg.configFile."hyprland-preview-share-picker/ember.css".text = ''
    .window, .window > box, .notebook > stack, .page {
      background-color: #${c.bg};
      color: #${c.fg};
    }
    .notebook > header {
      background-color: #${c.bgDeep};
      border-color: #${c.border};
    }
    .tab-label { color: #${c.fgDim}; }
    .notebook > header > tabs > tab:hover .tab-label { color: #${c.fg}; }
    .notebook > header > tabs > tab:checked .tab-label { color: #${c.accent}; }
    .notebook > header > tabs > tab:checked { box-shadow: inset 0 -2px #${c.accent}; }

    .page flowboxchild, .page button {
      background: none;
      border: none;
      box-shadow: none;
      outline: none;
    }
    .card {
      background-color: #${c.bgAlt};
      border: 2px solid transparent;
      border-radius: 8px;
      padding: 5px;
    }
    flowboxchild:hover > .card, button:hover > .card { background-color: #${c.surface}; }
    flowboxchild:selected > .card, flowboxchild:focus > .card,
    button:focus > .card, button:active > .card { border-color: #${c.accent}; }
    .image-label { color: #${c.fgSoft}; }

    .region-button {
      background: #${c.accent};
      color: #${c.bg};
      border: none;
      box-shadow: none;
    }
    .region-button:hover, .region-button:focus { background: #${c.accentBright}; }
    .region-button:disabled { background: #${c.border}; color: #${c.muted}; }

    .restore-button { color: #${c.fgSoft}; }
    .restore-button check:checked {
      background: #${c.accent};
      border-color: #${c.accent};
      color: #${c.bg};
    }
  '';
}
