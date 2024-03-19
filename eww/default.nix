{ config
, pkgs
, lib
, ...
}:
let
  inherit (lib) mdDoc;
  extraPkgs = with pkgs; [
    cfg.package
    pamixer
    brightnessctl
    iwgtk
    upower
    jaq
    jc
    blueberry
  ];

  cfg = config.programs.eww-hyprland;
in
{
  options.programs.eww-hyprland = {
    enable = lib.mkEnableOption (mdDoc "eww Hyprland config");

    package = lib.mkOption {
      type = with lib.types; nullOr package;
      default = pkgs.eww;
      defaultText = lib.literalExpression "pkgs.eww-wayland";
      description = mdDoc "Eww package to use.";
    };

    colors = lib.mkOption {
      type = with lib.types; nullOr lines;
      default = null;
      defaultText = lib.literalExpression "null";
      description = mdDoc ''
        SCSS file with colors defined in the same way as Catppuccin colors are,
        to be used by eww.

        Defaults to Catppuccin Mocha.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = extraPkgs;

    # remove nix files
    xdg.configFile."eww" = {
      source = lib.cleanSourceWith {
        filter = name: _type:
          let
            baseName = baseNameOf (toString name);
          in
          !(lib.hasSuffix ".nix" baseName) && (baseName != "_colors.scss");
        src = lib.cleanSource ./.;
      };

      # links each file individually, which lets us insert the colors file separately
      recursive = true;
    };

    # colors file
    xdg.configFile."eww/css/_colors.scss".text =
      if cfg.colors != null
      then cfg.colors
      else (builtins.readFile ./css/_colors.scss);
  };
}
