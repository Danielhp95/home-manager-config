{
  pkgs,
  lib,
  ...
}:
# Per-device EQ as WirePlumber software-dsp chains ("(EQ)" sinks, "Laptop
# Microphone"), each present only while its device is. hide-parent hides the
# raw device from all clients but WirePlumber (its volume stays fixed; drop it
# to A/B). A switch doesn't reload curves: restart the user wireplumber.
#
# One file per device in ./audio-eq/devices, written with the constructors in
# ./audio-eq/dsp.nix. A new device is a new file and a line below.
let
  dsp = import ./audio-eq/dsp.nix { inherit pkgs lib; };
in
{
  services.pipewire.wireplumber = {
    extraLv2Packages = [
      pkgs.lsp-plugins
      pkgs.calf
    ];
    extraConfig."60-eq-sinks" = {
      "wireplumber.profiles".main."node.software-dsp" = "required";
      "node.software-dsp.rules" = map (device: import device dsp) [
        ./audio-eq/devices/speakers.nix
        ./audio-eq/devices/shokz.nix
        ./audio-eq/devices/sony.nix
        ./audio-eq/devices/mic.nix
      ];
    };
  };
}
