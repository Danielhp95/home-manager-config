{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  programs.niri.enable = true;
  environment.systemPackages = with pkgs; [
    niriswitcher
    xwayland-satellite
    fuzzel
    swaylock-fancy
  ];
  # Useful reference from: https://github.com/YaLTeR/niri/wiki/Xwayland#using-xwayland-satellite
  # xwayland-run -geometry 800x600 -fullscreen -- wine wingame.exe
}
