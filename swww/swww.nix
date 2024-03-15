{ config, pkgs, lib, ... }:
let
  inherit (lib)
    concatStringsSep
    mdDoc
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.khome.desktop.swww;
  wallpaperDirs = concatStringsSep " " cfg.wallpaperDirs;
  singleRandom = "swww-randomise -i 0 ${wallpaperDirs}";
  startAndRandom = "swww-daemon init && swww-randomise -i 0 ${wallpaperDirs}";
  # startAndRandom = "systemctl --user start && swww-randomise -i 0 ${wallpaperDirs}";
  randomInterval = "sleep 60 && swww-randomise -i ${toString cfg.interval} -f ${toString cfg.fps} -s ${toString cfg.step} ${wallpaperDirs}";
in
{
  options.khome.desktop.swww = {
    enable = mkEnableOption (mdDoc "enable swww wallpapers");
    step = mkOption {
      default = 2;
      type = types.int;
      description = mdDoc "corresponds to SWWW_TRANSITION_FPS";
    };
    fps = mkOption {
      default = 60;
      type = types.int;
      description = mdDoc "corresponds to SWWW_TRANSITION_STEP";
    };
    interval = mkOption {
      default = 60;
      type = types.int;
      description = mdDoc "time interval in seconds between wallpaper changes";
    };
    wallpaperDirs = mkOption {
      default = [];
      type = types.listOf types.str;
      description = mdDoc "directories to source wallpapers from, matches png and jpg";
    };
  };

  config = mkIf cfg.enable {

    programs.hyprland = {
      binds."$mainMod SHIFT".I = "exec, ${singleRandom}";
      execOnce = {
        "swww-init" = startAndRandom;
        "swww-randomise" = randomInterval;
      };
    };

    wayland.windowManager.sway.config = {
      keybindings."$mod+Shift+i" = "exec ${singleRandom}";
      startup = mkAfter [
        { command = startAndRandom; }
        { command = randomInterval; }
      ];
    };

    home.packages = with pkgs; [
      swww
      (pkgs.writeScriptBin "swww-randomise" (builtins.readFile ./swww-randomise.nu))
    ];

  };
}
