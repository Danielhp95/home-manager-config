{ ... }:
{
  specialisation.dgpu-hdmi.configuration = {
    # hyprland.lua checks for this file to also open the NVIDIA card for
    # HDMI scanout (Intel stays the render GPU) — see the AQ_DRM_DEVICES
    # block in hyprland/hyprland.lua. Costs ~8W: the dGPU never
    # runtime-suspends while this specialisation is booted. Boot into it
    # from the GRUB menu when a monitor is wired to the NVIDIA GPU's ports;
    # boot the default entry otherwise for the dGPU to sleep.
    environment.etc."hypr-dgpu-hdmi".text = "";
  };
}
