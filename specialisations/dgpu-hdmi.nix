{ ... }:
{
  specialisation.dgpu-hdmi.configuration = {
    # GRUB entry title. Without it install-grub.pl falls back to
    # "(<name> - <date> - <version>)", and the date it uses is the mtime of
    # $toplevel/specialisation/<name> — a store path, so Nix has pinned it to
    # epoch+1 and every specialisation row on the menu reads 1969-12-31.
    boot.loader.grub.configurationName = "dGPU HDMI";

    # hyprland.lua checks for this file to also open the NVIDIA card for
    # HDMI scanout (Intel stays the render GPU) — see the AQ_DRM_DEVICES
    # block in hyprland/hyprland.lua. Costs ~8W: the dGPU never
    # runtime-suspends while this specialisation is booted. Boot into it
    # from the GRUB menu when a monitor is wired to the NVIDIA GPU's ports;
    # boot the default entry otherwise for the dGPU to sleep.
    environment.etc."hypr-dgpu-hdmi".text = "";
  };
}
