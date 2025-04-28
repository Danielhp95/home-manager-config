{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    gh
    fira-code
    powerline-fonts
  ];
  home.sessionVariables.TERM = "wezterm";
  programs = {
    # Terminal, ofc
    wezterm = {
      enable = true;
      extraConfig = builtins.readFile ./wezterm.lua;
      enableZshIntegration = true;
    };
    # Telescope inspired fzf for shell
    television = {
      enable = true;
      settings = {
        ui = {
          show_preview_panel = false;
          input_bar_position = "bottom";
        };
      };
    };
    # Really nice shell history
    atuin = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
      settings = {
        enter_accept = true; # Enter to execute, tab to select
        show_help = false;
        show_tabs = false;
        invert = true;
      };
    };
    # `ls` replacement
    eza.enable = true;
    # The one, the fuzzy searcher
    fzf.enable = true;
  };

}
