{ config, lib, pkgs, ... }:
with lib;
let cfg = config.khome.desktop.pyprland;
in {
  options.khome.desktop.pyprland = {
    enable = mkEnableOption "Enable Pyprland plugins for Hyprland";
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [ pyprland ];

      file = {
        ".config/hypr/pyprland.toml" = {
          text = ''
            [pyprland]
            plugins = [
              "fetch_client_menu",
              "magnify",
              "scratchpads"
            ]

            [scratchpads.terminal]
            animation = "fromTop"
            class = "pypr_scratchpad"
            command = "kitty"
            lazy = true
            size = "80% 80%"

            [scratchpads.filemanager]
            animation = "fromTop"
            class = "pypr_scratchpad"
            command = "thunar"
            lazy = true
            size = "80% 80%"

            [scratchpads.pavucontrol]
            animation = "fromTop"
            class = "pypr_scratchpad"
            command = "pavucontrol"
            lazy = false
            size = "70% 70%"
          '';
        };
      };
    };
  };
}
