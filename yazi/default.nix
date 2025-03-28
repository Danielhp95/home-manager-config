{
  pkgs,
  lib,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "273019910c1111a388dd20e057606016f4bd0d17";
    hash = "sha256-80mR86UWgD11XuzpVNn56fmGRkvj0af2cFaZkU8M31I=";
  };
in
{

  programs.yazi = {
    enable = true;
    # initLua = ./init.lua;
    enableZshIntegration = true;
    plugins = {
      # todo: https://github.com/boydaihungst/simple-mtpfs.yazi
      toggle-pane = "${officialPlugins}/toggle-pane.yazi";
      mount = "${officialPlugins}/mount.yazi";
      fg = pkgs.fetchFromGitHub {
        owner = "DreamMaoMao";
        repo = "fg.yazi";
        rev = "652d02a1413d2440d264667608102eb158ed0e68";
        hash = "sha256-/GApLVDpGcH2drwSNluEvoQdnjgE8AsPHdci/9eg7Lg=";
      };
    };
    keymap.manager.prepend_keymap = lib.flatten [
      {
        desc = "Mount tools";
        on = [ "M" ];
        run = "plugin mount";
      }
      {
        desc = "show help";
        on = [ "<c-h>" ];
        run = "help";
      }
      {
        desc = "open shell here";
        on = [
          "c"
          "c"
        ];
        run = "shell --block $SHELL";
      }
      {
        desc = "hide or show preview";
        on = [
          "m"
          "p"
        ];
        run = "plugin toggle-pane min-preview";
      }
      {
        desc = "max preview";
        on = [
          "m"
          "P"
        ];
        run = "plugin toggle-pane max-preview";
      }
      {
        desc = "Fuzzy search file contents";
        on = [
          "f"
          "g"
        ];
        run = "plugin fg rg";
      }
      {
        desc = "Fuzzy search file names";
        on = [
          "f"
          "f"
        ];
        run = "plugin fg fd";
      }
    ];
  };
  home.packages = with pkgs; [
    exiftool # Tool to read, write and edit EXIF meta information
    simple-mtpfs
  ];
}
