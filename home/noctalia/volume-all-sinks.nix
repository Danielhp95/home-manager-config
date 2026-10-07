# Steps every output at once (eq_* chains and hardware sinks), not just the
# default sink; a hardware sink an eq_*_out stream plays into is skipped so
# nothing steps twice. `mute` toggles them all as one group. On PATH
# (./bar.nix) because hyprland.lua, read verbatim, calls it by name.
{
  writeShellApplication,
  wireplumber,
  pipewire,
  jq,
}:
writeShellApplication {
  name = "volume-all-sinks";
  runtimeInputs = [
    wireplumber
    pipewire
    jq
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
}
