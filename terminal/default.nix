{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    gh
    fira-code
    powerline-fonts
    nix-search-tv
    rsync
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
      # enableZshIntegration = true;  # Not working
      channels = {
        my_custom = {
          cable_channel = [
            {
              name = "dart";
              source_command = "dart search --username-substrings daniel.hernandez";
              preview_command = "dart run get --config {0}";
            }
            {
              name = "nixpkgs";
              source_command = "nix-search-tv print";
              preview_command = "nix-search-tv preview {}";
            }
          ];
        };
      };
      settings = {
        ui = {
          use_nerd_font_icons = true;
          show_preview_panel = false;
          input_bar_position = "bottom";
        };
        # shell_ingetratrion = {
        #   channel_triggers = {
        #     files = [ "nvim" "cat" "less" "head" "tail" "vim" "nano" "bat" "cp" "mv" "rm" "touch" "chmod" "chown" "ln" "tar" "zip" "unzip" "gzip" "gunzip" "xz"];
        #     git-repos = ["git clone"];
        #   };
        # };
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
