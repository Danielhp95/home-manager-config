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
            ]
          '';
        };
      };
    };
  };
}
