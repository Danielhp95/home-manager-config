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
            command = "kitty"
            class = "Kitty"
            lazy = false
            size = "80% 80%"

            [scratchpads.filemanager]
            animation = "fromTop"
            command = "thunar"
            class = "nemo"
            lazy = true
            size = "60% 60%"

            [scratchpads.pavucontrol]
            animation = "fromTop"
            command = "pavucontrol"
            class = "Pavucontrol"
            lazy = true
            size = "70% 70%"
          '';
        };
      };
    };
  };
}
