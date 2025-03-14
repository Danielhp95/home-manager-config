{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "5186af7984aa8cb0550358aefe751201d7a6b5a8";
    hash = "sha256-Cw5iMljJJkxOzAGjWGIlCa7gnItvBln60laFMf6PSPM=";
  };
in
{
  # Hopefully this will work at some point

  xdg.configFile."yazi/plugins/mount.yazi".source = "${officialPlugins}/mount.yazi";

  programs.yazi = {
    enable = true;
    package = inputs.unstable.legacyPackages.x86_64-linux.yazi;
    # initLua = ./init.lua;
    enableZshIntegration = true;
    plugins = {
      # smart-enter = ./smart-enter;
      # parent-arrow = ./parent-arrow;
      # todo: https://github.com/boydaihungst/simple-mtpfs.yazi
      # chmod = "${officialPlugins}/chmod.yazi";
      # max-preview = "${officialPlugins}/max-preview.yazi";
      # hide-preview = "${officialPlugins}/hide-preview.yazi";
      fg = pkgs.fetchFromGitHub {
        owner = "DreamMaoMao";
        repo = "fg.yazi";
        rev = "f7d41ae71249515763d9ee04ddf4bdc3b0b42f55";
        hash = "sha256-6LpnyXB7mri6aVEfnv6aG2mWlzpvaD8SiMqwUS+jJr0=";
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
        run = "shell --block --confirm $shell";
      }
      {
        desc = "hide or show preview";
        on = [
          "m"
          "m"
        ];
        run = "plugin --sync hide-preview";
      }
      {
        desc = "Fuzzy search file contents";
        on = [
          "f"
          "g"
        ];
        run = "plugin fg --args='fzf'";
      }
    ];
    #   {
    #     desc = "enter the child directory, or open the file";
    #     on = [ "l" ];
    #     run = "plugin --sync smart-enter";
    #   }
    #   {
    #     desc = "navigate parent dir (up)";
    #     on = [ "k" ];
    #     run = "plugin --sync parent-arrow --args=-1";
    #   }
    #   {
    #     desc = "navigate parent dir (down)";
    #     on = [ "j" ];
    #     run = "plugin --sync parent-arrow --args=1";
    #   }
    #   {
    #     desc = "open lazygit";
    #     on = [ "<c-g>" ];
    #     run = ''shell "lazygit" --block --confirm'';
    #   }
    #   {
    #     desc = "tab delete";
    #     on = [
    #       "t"
    #       "d"
    #     ];
    #     run = "tab_close";
    #   }
    #   {
    #     desc = "tab next";
    #     on = [
    #       "t"
    #       "n"
    #     ];
    #     run = "tab_switch --relative 1";
    #   }
    #   {
    #     desc = "tab prev";
    #     on = [
    #       "t"
    #       "p"
    #     ];
    #     run = "tab_switch --relative -1";
    #   }
    #   {
    #     desc = "show tasks";
    #     on = [
    #       "t"
    #       "t"
    #     ];
    #     run = "tasks_show";
    #   }
    #   {
    #     desc = "maximize or restore preview";
    #     on = [
    #       "m"
    #       "m"
    #     ];
    #     run = "plugin --sync max-preview";
    #   }
    #   {
    #     desc = "chmod on selected files";
    #     on = [
    #       "c"
    #       "m"
    #     ];
    #     run = "plugin chmod";
    #   }
    # (optionals plugs.fg.enable [
    #   {
    #     desc = "find file by content";
    #     on = [
    #       "f"
    #       "g"
    #     ];
    #     run = "plugin fg";
    #   }
    #   {
    #     desc = "find file by file name";
    #     on = [
    #       "f"
    #       "f"
    #     ];
    #     run = "plugin fg --args='fzf'";
    #   }
    # ])
    # (optionals plugs.bookmarks.enable [
    #   {
    #     desc = "save current position as a bookmark";
    #     on = [
    #       "u"
    #       "a"
    #     ];
    #     run = "plugin bookmarks-persistence --args=save";
    #   }
    #   {
    #     desc = "jump to a bookmark";
    #     on = [
    #       "u"
    #       "g"
    #     ];
    #     run = "plugin bookmarks-persistence --args=jump";
    #   }
    #   {
    #     desc = "delete a bookmark";
    #     on = [
    #       "u"
    #       "d"
    #     ];
    #     run = "plugin bookmarks-persistence --args=delete";
    #   }
    #   {
    #     desc = "delete all bookmarks";
    #     on = [
    #       "u"
    #       "d"
    #     ];
    #     run = "plugin bookmarks-persistence --args=delete_all";
    #   }
    # ])
    # ];

  };
  home.packages = with pkgs; [
    exiftool # Tool to read, write and edit EXIF meta information
    # checkout https://github.com/boydaihungst/simple-mtpfs.yazi
    # to see how to set this up
    simple-mtpfs
  ];
}
