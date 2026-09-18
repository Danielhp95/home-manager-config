{lib, ...}:
{
  specialisation.roadwarrior.configuration = {
    # GRUB entry title. Without it install-grub.pl falls back to
    # "(<name> - <date> - <version>)", and the date it uses is the mtime of
    # $toplevel/specialisation/<name> — a store path, so Nix has pinned it to
    # epoch+1 and every specialisation row on the menu reads 1969-12-31.
    boot.loader.grub.configurationName = "Roadwarrior";

    imports = [ ../hardwares/disable_nvidia.nix ];
    home-manager.users.dani.wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      # lib.mkAfter ensure that this part of the config gets added at the end
      # extraConfig = lib.mkAfter ''
      #   # Exploiting configuration overriding
      #   animations {
      #     enabled = false
      #   }
      #   # Which GPU to run Hyprland on. To find card names: ls -l /dev/dri/by-path
      #   env = AQ_DRM_DEVICES, /dev/dri/card0:/dev/dri/card1  # Try amdgpu, otherwise NVIDIA, which should be disabled
      # '';
    };
  };
}
