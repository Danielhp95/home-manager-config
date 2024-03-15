{pkgs, ...}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    plugins = [ pkgs.hy3 ]; # make sure we are targetting the same version of hyprland and hy3
  };
  home.file.".config/hypr/hyprpaper.conf".source = ./hyprpaper.conf;
  home.file.".config/hypr/hyprlock.conf".source = ./hyprlock.conf;
  home.packages = with pkgs; [
    hyprlock
    hyprcursor

    grimblast
    swww
    mako
    fcitx5
    imv
    mpv
  ];
}
