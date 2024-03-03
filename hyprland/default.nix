{pkgs, ...}:
{
  wayland.windowManager.hyprland.enable = true;
  # wayland.windowManager.hyprland.enableNvidiaPatches = true;
  wayland.windowManager.hyprland.extraConfig = builtins.readFile ./hyprland.conf;
}
