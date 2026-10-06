{
  pkgs,
  lib,
  ...
}:
let
  p = (import ../../palette).hash;

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
      # Every mount action lives under M (a which-key menu), the only free
      # prefix in yazi's preset keymap: M m is mount.yazi's udisks UI, M p the
      # GVfs devices. The menu lists candidates in binding order.
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
        desc = "Jump to a mounted device";
        on = [
          "M"
          "j"
        ];
        run = "plugin gvfs -- jump-to-device";
      }
      {
        desc = "Back to where you were before the device";
        on = [
          "M"
          "b"
        ];
        run = "plugin gvfs -- jump-back-prev-cwd";
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
    # Ember from ../../palette/. yazi silently ignores unknown theme keys, so a
    # typo or renamed key just reverts to the preset (v26 moved the hover styles
    # from [mgr] to [indicator]). No [app].overall bg: the terminal paints it.
    theme = {
      mgr = {
        cwd = {
          fg = p.gold;
          bold = true;
        };
        find_keyword = {
          fg = p.accent;
          bold = true;
          underline = true;
        };
        find_position = {
          fg = p.mauve;
          bg = "reset";
          bold = true;
        };
        # Markers are drawn as empty cells, fg+bg the same color on purpose.
        marker_copied = {
          fg = p.olive;
          bg = p.olive;
        };
        marker_cut = {
          fg = p.error;
          bg = p.error;
        };
        marker_marked = {
          fg = p.sage;
          bg = p.sage;
        };
        marker_selected = {
          fg = p.accent;
          bg = p.accent;
        };
        count_copied = {
          fg = p.bg;
          bg = p.olive;
        };
        count_cut = {
          fg = p.bg;
          bg = p.error;
        };
        count_selected = {
          fg = p.bg;
          bg = p.accent;
        };
        border_symbol = "│";
        # accentDim, not p.border: kitty antialiases border glyphs, and a border
        # barely lighter than the background fades to dashes (as in danvim).
        border_style.fg = p.accentDim;
      };

      # Hovered row: filetype fg on a surface bg, like fzf/television; the
      # preset's reverse video turns every hover into a loud pill.
      indicator = {
        parent.bg = p.surface;
        current.bg = p.surface;
        preview.underline = true;
      };

      tabs = {
        active = {
          fg = p.bg;
          bg = p.accent;
          bold = true;
        };
        inactive = {
          fg = p.fgDim;
          bg = p.bgAlt;
        };
      };

      mode = {
        normal_main = {
          fg = p.bg;
          bg = p.accent;
          bold = true;
        };
        normal_alt = {
          fg = p.accent;
          bg = p.bgAlt;
        };
        select_main = {
          fg = p.bg;
          bg = p.olive;
          bold = true;
        };
        select_alt = {
          fg = p.olive;
          bg = p.bgAlt;
        };
        unset_main = {
          fg = p.bg;
          bg = p.mauve;
          bold = true;
        };
        unset_alt = {
          fg = p.mauve;
          bg = p.bgAlt;
        };
      };

      status = {
        progress_label.bold = true;
        progress_normal = {
          fg = p.accent;
          bg = p.bgAlt;
        };
        progress_error = {
          fg = p.error;
          bg = p.bgAlt;
        };
        perm_type.fg = p.steel;
        perm_read.fg = p.gold;
        perm_write.fg = p.error;
        perm_exec.fg = p.olive;
        perm_sep.fg = p.muted;
      };

      which = {
        mask.bg = p.bgDeep;
        cand.fg = p.accent;
        rest.fg = p.fgDim;
        desc.fg = p.fg;
        separator_style.fg = p.muted;
      };

      confirm = {
        border.fg = p.accentDim;
        title = {
          fg = p.gold;
          bold = true;
        };
        btn_yes = {
          fg = p.olive;
          bold = true;
        };
        btn_no.fg = p.error;
      };

      spot = {
        border.fg = p.accentDim;
        title = {
          fg = p.gold;
          bold = true;
        };
        tbl_col = {
          fg = p.accent;
          bold = true;
        };
        tbl_cell = {
          fg = p.gold;
          reversed = true;
        };
      };

      notify = {
        title_info.fg = p.sage;
        title_warn.fg = p.gold;
        title_error.fg = p.error;
      };

      pick = {
        border.fg = p.accentDim;
        active = {
          fg = p.accent;
          bold = true;
        };
        inactive.fg = p.fgDim;
      };

      input = {
        border.fg = p.accentDim;
        title.fg = p.gold;
        value.fg = p.fg;
        selected.bg = p.border;
      };

      cmp = {
        border.fg = p.accentDim;
        active = {
          fg = p.accent;
          bg = p.surface;
        };
        inactive.fg = p.fgDim;
      };

      tasks = {
        border.fg = p.accentDim;
        title.fg = p.gold;
        hovered = {
          bg = p.surface;
          underline = true;
        };
      };

      # Help is a command palette (yazi #4074): `chord` is the key column,
      # `action` the description; its filter line is styled by [input].
      help = {
        border.fg = p.accentDim;
        chord.fg = p.accent;
        action.fg = p.fg;
        hovered = {
          bg = p.surface;
          bold = true;
        };
      };

      # First match wins; `is` conditions go before the broad mime globs.
      filetype.rules = [
        # Gold: folders are what you navigate by (as with zsh paths)
        {
          url = "*/";
          fg = p.gold;
          bold = true;
        }
        {
          is = "orphan";
          url = "*";
          fg = p.error;
          crossed = true;
        }
        {
          is = "link";
          url = "*";
          fg = p.sage;
        }
        {
          is = "exec";
          url = "*";
          fg = p.olive;
        }
        {
          mime = "image/*";
          fg = p.gold;
        }
        {
          mime = "{audio,video}/*";
          fg = p.mauve;
        }
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          fg = p.accent;
        }
      ];

      # Folder icons in burnt orange instead of the preset's blues. The preset
      # colors dirs twice, via an `if = "dir"` cond and via per-name `dirs` that
      # outrank any cond, so the XDG set, .git and .config are re-pinned here.
      icon = {
        # Icon rules don't merge — an entry without `text` would blank the
        # glyph — so these carry the preset's own glyphs, recolored.
        prepend_dirs =
          map
            (d: {
              name = d.n;
              text = d.t;
              fg = p.accentDim;
            })
            [
              {
                n = ".config";
                t = "";
              }
              {
                n = ".git";
                t = "";
              }
              {
                n = "Desktop";
                t = "";
              }
              {
                n = "Documents";
                t = "";
              }
              {
                n = "Downloads";
                t = "";
              }
              {
                n = "Music";
                t = "";
              }
              {
                n = "Pictures";
                t = "";
              }
              {
                n = "Videos";
                t = "";
              }
            ];
        # Prepended, so these outrank the preset's dir conds; "dir & hovered"
        # must precede "dir" or it never matches.
        prepend_conds = [
          {
            "if" = "dir & hovered";
            text = "";
            fg = p.accentDim;
          }
          {
            "if" = "dir";
            text = "";
            fg = p.accentDim;
          }
        ];
      };
    };

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
  # yazi as the file dialog of every app that asks the desktop portal for one
  # (the system side is xdg.portal in nixos/default.nix). The portal backend
  # runs file-chooser.nu, which opens yazi in a floating kitty: Enter on a file
  # picks it, q cancels. For a save, the suggested file is created as a
  # placeholder and hovered; move or rename it to save elsewhere, after which
  # Enter and q both save.
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.writers.writeNu "yazi-file-chooser" (builtins.readFile ./file-chooser.nu)}
    default_dir=$HOME
  '';

  # GTK apps draw their own file dialog unless told to ask the portal
  # (GTK_USE_PORTAL is GTK3's switch, GDK_DEBUG=portals GTK4's). It also sends
  # their "open this link" through the portal. Read at login.
  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    GDK_DEBUG = "portals";
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
