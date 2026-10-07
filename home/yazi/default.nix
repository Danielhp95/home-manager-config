{
  pkgs,
  lib,
  theme,
  ...
}:
let
  p = theme.hash;

  # https://github.com/yazi-rs/plugins — this pin MUST track nixpkgs' yazi
  # (26.9.1; this rev targets 26.8.15 and runs clean on 26.9.1): the plugin API
  # is versioned and a mismatch only fails at runtime (e.g. yazi #4235's fetchers).
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "6f26ae04ba2e4763faada6a7997ae8b57c158cdb";
    hash = "sha256-pySI+LxiGmGEp/cvVXtuOuNzvy3c2QC6zuoTjActPbw=";
  };
in
{
  imports = [ ./file-chooser.nix ];

  programs.yazi = {
    enable = true;
    # No cd-on-exit wrapper in any shell (zsh has `fm`). The
    # name stays pinned so HM's 26.05 default-change warning can't fire.
    shellWrapperName = "yy";
    enableZshIntegration = false;
    enableNushellIntegration = false;
    initLua = ./init.lua;
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
        rev = "971b85862a1a2c5b8133da88b0dd4569adff296e";
        hash = "sha256-pbwKj4NuIiBMyuRVtbOYWBREZbyg1mKLoCWIAkxrygc=";
      };
      restore = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "restore.yazi";
        rev = "7bfcfcbda078b7e51d1ff9a62db9c654a3952fa4";
        hash = "sha256-pmyS1rU5C6U9LloGoDFB8s6GwoMqG1Jve5OFooI64tU=";
      };
      # Thumbnail + metadata preview (needs mediainfo, ffmpeg and imagemagick)
      mediainfo = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "mediainfo.yazi";
        rev = "e079a001f4fefd69007e515bbede4e16b95a811e";
        hash = "sha256-RIVcKJO89R4oaE6sJuFcV8pFK4nvWtq6ILAXehu4FIY=";
      };
      # Phones (MTP), cameras and network shares via GVfs; the system side is
      # services.gvfs and services.udisks2 in nixos/default.nix.
      gvfs = pkgs.fetchFromGitHub {
        owner = "boydaihungst";
        repo = "gvfs.yazi";
        rev = "ebdb87c9783d302a0129911c31c0ae3eb27a5c9f";
        hash = "sha256-0vW2LBv0r3N91wy5ajra8b0jPeLJ89iE0kP/meTVc7U=";
      };
    };
    keymap.mgr.prepend_keymap = import ./keymap.nix { inherit lib; };
    theme = import ./theme.nix { inherit lib p; };

    settings = {
      mgr = {
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
        # mediainfo.yazi replaces the built-in image/video previewers. GVfs
        # mounts are too slow to preview from, so noop them first (first match
        # wins); an absolute path because env vars don't expand here (uid 1000).
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
    trash-cli # required by restore.yazi
    mediainfo # required by mediainfo.yazi (ffmpeg comes from ../default.nix)
    # `gio`, which every gvfs.yazi action shells out to: services.gvfs ships
    # only the daemons, the CLI lives in glib.
    glib
  ];
}
