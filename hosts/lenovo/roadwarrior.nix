{ inputs, lib, ... }:
{
  specialisation.roadwarrior.configuration = {
    # GRUB entry title; without it the row is dated from the specialisation's
    # store-path mtime, i.e. 1969-12-31.
    boot.loader.grub.configurationName = "Roadwarrior";

    # Takes the dGPU off the PCI bus (blacklists nouveau/nvidia and has udev
    # remove every NVIDIA PCI function); hyprland.lua then runs Intel-only.
    imports = [ inputs.nixos-hardware.nixosModules.common-gpu-nvidia-disable ];

    # Overrides the main config's [ "nvidia" ]: the driver stack must stay off.
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
  };
}
