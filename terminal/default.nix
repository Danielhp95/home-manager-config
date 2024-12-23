{ pkgs, inputs, ...}:
{
  home.packages = with pkgs; [
    gh
    fira-code
    powerline-fonts
  ];
  home.sessionVariables.TERM = "wezterm";
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ./wezterm.lua;
    enableZshIntegration = true;
  };
}
