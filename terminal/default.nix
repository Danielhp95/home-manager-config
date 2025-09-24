{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    gh
    fira-code
    powerline-fonts
    nix-search-tv
    rsync
  ];
  home.sessionVariables.TERM = "kitty";
  programs = {
    wezterm = {
      enable = true;
      extraConfig = builtins.readFile ./wezterm.lua;
      enableZshIntegration = true;
    };
    pay-respects = {
      enable = true;
      enableZshIntegration = true;
    };
    btop = {
      package = pkgs.btop-cuda;
      enable = true;
      settings = {
        shown_boxes = "cpu proc";
        vim_keys = true;
        rounded_corners = true;
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
