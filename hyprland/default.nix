{pkgs, inputs, ...}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    plugins = [ pkgs.hy3 ]; # make sure we are targetting the same version of hyprland and hy3
  };
  home.file.".config/wal/templates/colors-hyprland.conf".source = ./colors-hyprland.conf;
  home.packages = with pkgs; [
    hyprlock
    hyprcursor

    grimblast

    imv
    mpv

    pw-volume
    inputs.stable.legacyPackages.x86_64-linux.librime
  ];
}
