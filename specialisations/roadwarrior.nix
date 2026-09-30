{
  specialisation.roadwarrior.configuration = {
    # GRUB entry title; without it the row is dated from the specialisation's
    # store-path mtime, i.e. 1969-12-31.
    boot.loader.grub.configurationName = "Roadwarrior";

    # Takes the dGPU off the PCI bus; hyprland.lua then runs Intel-only.
    imports = [ ../hardwares/disable_nvidia.nix ];
  };
}
