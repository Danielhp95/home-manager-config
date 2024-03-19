{ pkgs, ...}:
{
  home.packages = with pkgs; [
    gh
    (nerdfonts.override { fonts = [ "FiraCode" "Iosevka" ]; })
  ];
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ./wezterm.lua;
  };
}
