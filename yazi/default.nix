{
  pkgs,
  lib,
  ...
}:
let
  # https://github.com/yazi-rs/plugins — keep this pin roughly in sync with the
  # yazi version from nixpkgs (currently 26.5.6).
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "8cd50c622898d3ace3ca821f540241965308289a";
    sha256 = "sha256-f4y952sUF/lrHMX6enQts/obk2DeatqAcaVHfjTD65k=";
  };
in
{

  programs.yazi = {
    enable = true;
    # Pin legacy wrapper name (26.05 changed the default from "yy" to "y").
    shellWrapperName = "yy";
    initLua = ./init.lua;
    enableZshIntegration = true;
    plugins = {
      # todo: https://github.com/boydaihungst/simple-mtpfs.yazi
      toggle-pane = "${officialPlugins}/toggle-pane.yazi";
      mount = "${officialPlugins}/mount.yazi";
      vcs-files = "${officialPlugins}/vcs-files.yazi";
      zoom = "${officialPlugins}/zoom.yazi";
      chmod = "${officialPlugins}/chmod.yazi";
      smart-enter = "${officialPlugins}/smart-enter.yazi";
      git = "${officialPlugins}/git.yazi";
      full-border = "${officialPlugins}/full-border.yazi";
      # Local plugin: cd to sibling dirs of the parent from anywhere (K/J on parent pane)
      parent-arrow = ./parent-arrow;
      fg = pkgs.fetchFromGitHub {
        owner = "DreamMaoMao";
        repo = "fg.yazi";
        rev = "46a5c16f62f415f691319f984b9548249b0edc96";
        hash = "sha256-B6Feg8icshHQYv04Ee/Bo9PPaiDPRyt1HwpirI/yXj8=";
      };
      tv = pkgs.fetchFromGitHub {
        owner = "cap153";
        repo = "tv.yazi";
        rev = "b6b1f123bec3e0db59bc2e4dce929e116a5465a3";
        hash = "sha256-VIs8BYbXbXVSrlKpmYAhuahIiWR4PWzjKZvOm+J6TBk=";
      };
      compress = pkgs.fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "e60e122e565e7c4798ef22767eb363428dc6704e";
        hash = "sha256-yts/LCDpCH9cH1pY6Im/UpCQDCyzjhSGDZfGpQDdEZc=";
      };
      yamb = pkgs.fetchFromGitHub {
        owner = "h-hg";
        repo = "yamb.yazi";
        rev = "5f2e22e784dd5fc830cd85885a6d1d6690b52298";
        hash = "sha256-3Cp3+v0laSVsDdTyG26EOh2xt18ER8P9Nla9vtRuj9k=";
      };
      restore = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "restore.yazi";
        rev = "0e0870460b9b74c5ae98b7f96c7c26a9a274ce6d";
        hash = "sha256-rDsyMF5IEBHx+fJ0oYTCCQAlTSquUcOkFLC4Lmbuz6k=";
      };
    };
    keymap.mgr.prepend_keymap = lib.flatten [
      {
        desc = "Show Git file changes";
        on = [
          "g"
          "c"
        ];
        run = "plugin vcs-files";
      }
      {
        desc = "Jump to a file via television";
        on = [ "<c-f>" ];
        run = "plugin tv";
      }
      {
        desc = "Jump to a directory via television";
        on = [ "<c-d>" ];
        run = "plugin tv dirs";
      }
      {
        desc = "Open files using neovim and jump to where the string is located";
        on = [ "<C-g>" ];
        run = "plugin tv text";
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
        desc = "open lazygit here";
        on = [
          "g"
          "l"
        ];
        run = "shell --block lazygit";
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
        on = "+";
        run = "plugin zoom 1";
        desc = "Zoom in hovered file";
      }
      {
        on = "-";
        run = "plugin zoom -1";
        desc = "Zoom out hovered file";
      }
      {
        desc = "Enter dir / open file with one key";
        on = [ "l" ];
        run = "plugin smart-enter";
      }
      {
        desc = "Chmod selected files";
        on = [
          "c"
          "m"
        ];
        run = "plugin chmod";
      }
      {
        desc = "Archive selected files";
        on = [
          "c"
          "a"
        ];
        run = "plugin compress";
      }
      # Move to sibling dir of the parent without leaving cwd
      {
        desc = "Parent dir up";
        on = [ "K" ];
        run = "plugin parent-arrow -1";
      }
      {
        desc = "Parent dir down";
        on = [ "J" ];
        run = "plugin parent-arrow 1";
      }
      # Trash restore (needs trash-cli)
      {
        desc = "Restore last deleted files/folders";
        on = [
          "d"
          "u"
        ];
        run = "plugin restore";
      }
      # Bookmarks (yamb)
      {
        desc = "Add bookmark";
        on = [
          "u"
          "a"
        ];
        run = "plugin yamb -- save";
      }
      {
        desc = "Jump bookmark by key";
        on = [
          "u"
          "g"
        ];
        run = "plugin yamb -- jump_by_key";
      }
      {
        desc = "Jump bookmark by fzf";
        on = [
          "u"
          "G"
        ];
        run = "plugin yamb -- jump_by_fzf";
      }
      {
        desc = "Delete bookmark by key";
        on = [
          "u"
          "d"
        ];
        run = "plugin yamb -- delete_by_key";
      }
      {
        desc = "Delete all bookmarks";
        on = [
          "u"
          "A"
        ];
        run = "plugin yamb -- delete_all";
      }
    ];
    settings = {
      mgr = {
        # Show file sizes in the listing
        linemode = "size";
      };
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
      plugin = {
        # git.yazi status signs next to filenames
        prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
      };
    };
  };
  home.packages = with pkgs; [
    exiftool # Tool to read, write and edit EXIF meta information
    simple-mtpfs
    imagemagick # For resizing preview images
    lazygit # g l binding
    trash-cli # required by restore.yazi
  ];
}
