{
  specialisation.roadwarrior.configuration = {
    # GRUB entry title. Without it install-grub.pl dates the row from the
    # specialisation's store-path mtime, which Nix pins to epoch+1
    # (1969-12-31).
    boot.loader.grub.configurationName = "Roadwarrior";

    # Removes the dGPU from the PCI bus; hyprland.lua then finds no NVIDIA
    # card and runs on the Intel iGPU alone.
    imports = [ ../hardwares/disable_nvidia.nix ];
  };
}
