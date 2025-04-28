{
  pkgs,
  lib,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "4b027c79371af963d4ae3a8b69e42177aa3fa6ee";
    sha256 = "sha256-auGNSn6tX72go7kYaH16hxRng+iZWw99dKTTUN91Cow=";
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
      vcs-files = "${officialPlugins}/vcs-files.yazi";
      fg = pkgs.fetchFromGitHub {
        owner = "DreamMaoMao";
        repo = "fg.yazi";
        rev = "652d02a1413d2440d264667608102eb158ed0e68";
        hash = "sha256-/GApLVDpGcH2drwSNluEvoQdnjgE8AsPHdci/9eg7Lg=";
      };
    };
    keymap.manager.prepend_keymap = lib.flatten [
      {
        on = [
          "g"
          "c"
        ];
        run = "plugin vcs-files";
        desc = "Show Git file changes";
      }
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
