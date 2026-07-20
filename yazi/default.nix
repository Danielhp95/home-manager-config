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
      # Thumbnail + metadata (ISO, aperture, codec, bitrate, ...) preview for
      # images/videos/audio. Needs mediainfo, ffmpeg and imagemagick.
      mediainfo = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "mediainfo.yazi";
        rev = "e079a001f4fefd69007e515bbede4e16b95a811e";
        hash = "sha256-RIVcKJO89R4oaE6sJuFcV8pFK4nvWtq6ILAXehu4FIY=";
      };
      # Mount Android phones (MTP), cameras and network shares via GVfs
      # (successor of simple-mtpfs.yazi). The system side — gvfsd, gvfsd-mtp,
      # libmtp udev rules, udisks2 — is already provided by services.gvfs,
      # pulled in by the GNOME module in configuration.nix.
      gvfs = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "gvfs.yazi";
        rev = "c5a0bb924eceeeb8b44bfc00aba0a97ba0287fa3";
        hash = "sha256-hSHEN/F4uc1FFScB5lLRAKryLwP+O7I9vgEgobGbQyw=";
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
      # Mounting: everything lives under the M prefix (which-key menu).
      # M m opens the classic mount.yazi UI (udisks disks/partitions), so the
      # pre-gvfs muscle memory of "M then m" still lands there; phones and
      # other GVfs devices are on M p.
      {
        desc = "Mount disks/partitions (udisks)";
        on = [
          "M"
          "m"
        ];
        run = "plugin mount";
      }
      {
        desc = "Mount phone/device (MTP) and jump to it";
        on = [
          "M"
          "p"
        ];
        run = "plugin gvfs -- select-then-mount --jump";
      }
      {
        desc = "Unmount/eject device";
        on = [
          "M"
          "u"
        ];
        run = "plugin gvfs -- select-then-unmount --eject";
      }
      {
        desc = "Force unmount/eject device";
        on = [
          "M"
          "U"
        ];
        run = "plugin gvfs -- select-then-unmount --eject --force";
      }
      {
        desc = "Add a GVfs mount URI (smb, sftp, ftp, ...)";
        on = [
          "M"
          "a"
        ];
        run = "plugin gvfs -- add-mount";
      }
      {
        desc = "Edit a GVfs mount URI";
        on = [
          "M"
          "e"
        ];
        run = "plugin gvfs -- edit-mount";
      }
      {
        desc = "Remove a GVfs mount URI";
        on = [
          "M"
          "r"
        ];
        run = "plugin gvfs -- remove-mount";
      }
      {
        desc = "Jump to a mounted device";
        on = [
          "g"
          "m"
        ];
        run = "plugin gvfs -- jump-to-device";
      }
      {
        desc = "Jump back to where you were before the device";
        on = [
          "`"
          "`"
        ];
        run = "plugin gvfs -- jump-back-prev-cwd";
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
        # mediainfo.yazi: thumbnail + metadata preview; replaces the built-in
        # image/video previewers (it renders the image itself, then the info).
        # GVfs mounts (MTP phones, network shares) are too slow to preload or
        # preview files from — noop them first (first match wins). Absolute
        # path because env vars don't expand here; 1000 = dani's uid.
        prepend_preloaders = [
          {
            url = "/run/user/1000/gvfs/**/*";
            run = "noop";
          }
          {
            mime = "{audio,video,image}/*";
            run = "mediainfo";
          }
        ];
        prepend_previewers = [
          # Keep folder listings working everywhere, incl. GVfs mounts
          {
            url = "*/";
            run = "folder";
          }
          {
            url = "/run/user/1000/gvfs/**/*";
            run = "noop";
          }
          {
            mime = "{audio,video,image}/*";
            run = "mediainfo";
          }
        ];
      };
    };
  };
  home.packages = with pkgs; [
    exiftool # Tool to read, write and edit EXIF meta information
    imagemagick # For resizing preview images
    lazygit # g l binding
    trash-cli # required by restore.yazi
    mediainfo # required by mediainfo.yazi (ffmpeg comes from home.nix)
  ];
}
