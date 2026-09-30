{ lib, inputs, ... }:
{
  # Blacklists nouveau and the nvidia modules, and has udev remove every NVIDIA
  # PCI function (GPU, HDMI audio, USB-C) as it appears.
  imports = [ inputs.nixos-hardware.nixosModules.common-gpu-nvidia-disable ];

  # The main config sets videoDrivers = [ "nvidia" ]; with the card gone, the
  # nvidia driver stack must not be enabled at all.
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
}
