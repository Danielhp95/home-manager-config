{
  specialisation.roadwarrior.configuration = {
    # GRUB entry title. Without it install-grub.pl dates the row from the
    # specialisation's store-path mtime, which Nix pins to epoch+1
    # (1969-12-31).
    boot.loader.grub.configurationName = "Roadwarrior";

    imports = [ ../hardwares/disable_nvidia.nix ];
    # disable_nvidia.nix removes the dGPU from the PCI bus, so there is no card
    # for Hyprland to open (hardwares/lenovo_t16g_gen3.nix).
    environment.etc."hypr-dgpu-hdmi".enable = false;
  };
}
