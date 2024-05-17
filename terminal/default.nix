{ pkgs, ...}:
{
  home.packages = with pkgs; [
    gh
    (nerdfonts.override { fonts = [ "FiraCode" "Iosevka" ]; })
  ];
  home.sessionVariables.TERM = "wezterm";
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ./wezterm.lua;
    enableZshIntegration = true;
  };
}
