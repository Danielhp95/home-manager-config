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
    television = {
      enable = true;
      enableZshIntegration = true;
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
