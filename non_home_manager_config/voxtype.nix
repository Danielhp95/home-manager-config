{ config, pkgs, ... }:

{
  # https://sourcegraph.com/r/github.com/knoopx/nix/-/blob/modules/home-manager/programs/voxtype.nix?L32-34
  ########################################
  # Packages
  ########################################

  ########################################
  # uinput (required for typing on Wayland)
  ########################################
  boot.kernelModules = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input"
  '';

  users.users.dani = {
    extraGroups = [ "input" ];
  };

  ########################################
  # PipeWire (low latency audio)
  ########################################
  services.pipewire = {
    enable = true;
    pulse.enable = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  ########################################
  # (Optional but recommended) security
  ########################################
  security.rtkit.enable = true;
}
