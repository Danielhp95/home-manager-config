{lib, ...}:
{
  specialisation.roadwarrior.configuration = {
    imports = [ ../hardwares/disable_nvidia.nix ];
    home-manager.users.daniel.wayland.windowManager.hyprland = {
      enable = true;
      # lib.mkAfter ensure that this part of the config gets added at the end
      extraConfig = lib.mkAfter ''
        # Exploiting configuration overriding
        animations {
          enabled = false
        }
        # Which GPU to run Hyprland on. To find card names: ls -l /dev/dri/by-path
        env = AQ_DRM_DEVICES, /dev/dri/card0:/dev/dri/card1  # Try amdgpu, otherwise NVIDIA, which should be disabled
      '';
    };
  };
}
