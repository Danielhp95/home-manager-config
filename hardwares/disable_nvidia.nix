{ lib, inputs, ... }:
{
  # Blacklists nouveau/nvidia and has udev remove every NVIDIA PCI function.
  imports = [ inputs.nixos-hardware.nixosModules.common-gpu-nvidia-disable ];

  # Overrides the main config's [ "nvidia" ]: the driver stack must stay off.
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
}
