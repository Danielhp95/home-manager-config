{
  pkgs,
  lib,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "c648526665f6fb466150e9ee41aa0431b87cb041";
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
      zoom = "${officialPlugins}/zoom.yazi";
      fg = pkgs.fetchFromGitHub {
        owner = "DreamMaoMao";
        repo = "fg.yazi";
        rev = "46a5c16f62f415f691319f984b9548249b0edc96";
        hash = "sha256-/GApLVDpGcH2drwSNluEvoQdnjgE8AsPHdci/9eg7Lg=";
      };
      # TODO: add https://github.com/KKV9/compress.yazi
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
      {
        on = "+";
        run = "plugin zoom 1";
        desc = "Zoom in hovered file";
      }
      {
        on = "-";
        run = "plugin zoom -1";
        desc = "Zoom out hovered file";
      }
    ];
    settings = {
      tasks = {
        # To render images past a given size
        image_bound = [
          10000
          10000
        ];
      };
      input = {
        cursor_blink = true;
      };
    };
  };
  home.packages = with pkgs; [
    exiftool # Tool to read, write and edit EXIF meta information
    simple-mtpfs
    imagemagick  # For resizing preview images
  ];
}
