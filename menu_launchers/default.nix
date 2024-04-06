{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    configPath = "./config.rasi";
    theme = "./spotlight_dark.rasi";
    #terminal = "${pkgs.kitty}/bin/kitty";
    plugins = with pkgs; [
      rofi-file-browser
      rofi-pulse-select
      rofi-power-menu
      rofi-pulse-select
    ];
  };
  programs.fuzzel = {
    enable = true;
    # settings = ./fuzzel/config.ini;
  };
}
