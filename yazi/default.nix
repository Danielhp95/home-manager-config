{
  pkgs,
  lib,
  ...
}:
let
  p = (import ../palette.nix).hash;

  # https://github.com/yazi-rs/plugins — this pin MUST track the yazi version
  # from nixpkgs (currently 26.8.15): the plugin API is versioned, and a plugin
  # built for an older yazi fails at runtime, not at build time. 26.8.15 reworked
  # the fetcher API (yazi #4235) — fetchers now return a `ya.co(...)` coroutine
  # instead of a boolean, so the older git.yazi died with
  # "error converting lua boolean to function" on every fetch.
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "6f26ae04ba2e4763faada6a7997ae8b57c158cdb";
    sha256 = "sha256-pySI+LxiGmGEp/cvVXtuOuNzvy3c2QC6zuoTjActPbw=";
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
      # libmtp udev rules, udisks2 — comes from services.gvfs and
      # services.udisks2, enabled explicitly in configuration.nix.
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
    # Ember, straight from ../palette.nix — yazi ran on stock colors before.
    # Key names are validated against yazi 26.5.6 by actually running it: yazi
    # silently ignores unknown theme keys (no warning, no error), so a typo or
    # a renamed key just quietly reverts that element to the preset. Notably
    # v26 moved the hovered-row styles out of [mgr] (hovered/preview_hovered)
    # into [indicator] (parent/current/preview) — the old names still "work"
    # in the sense that nothing complains.
    #
    # No [app].overall bg: the terminal already paints the ember background
    # (with its opacity), yazi shouldn't repaint it opaque.
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
        # accentDim, not p.border: same lesson as the nvim float borders — kitty
        # rasterizes the border glyphs as antialiased shapes, and a border a few
        # percent lightness above the background loses its partial-coverage
        # pixels (worse here, through background_opacity). p.border reads as
        # barely-there dashes; accentDim matches the danvim FloatBorder pick.
        border_style.fg = p.accentDim;
      };

      # The hovered row: file's own filetype fg kept, surface bg behind it —
      # same recipe as the fzf/television selected row. The preset default is
      # reversed video, which turns every hover into a loud full-color pill.
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

      # v26.8.15 made the help menu a command palette (yazi #4074) and renamed
      # its theme keys with it: `on` -> `chord` (the key column, 20 cells wide),
      # `run` + `desc` collapsed into a single `action` (the row prints the
      # description, falling back to the raw command), and `footer` is gone —
      # the palette's filter line is an Input, styled by [input] above. The old
      # names were silently ignored, so help rendered on preset colors.
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
        # Gold, not steel: folders are what you navigate by, so they carry
        # the emphasis color (same request as zsh paths).
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

      # Folder icons in burnt orange instead of the preset's blues. Two rules
      # because the preset colors dirs in two places with different priority:
      # a cond (`if = "dir"` → #03a9f4) for generic folders, and per-name
      # `dirs` entries (Desktop, Downloads, ... → #00bcd4 cyan) that outrank
      # any cond — so the XDG home set is re-pinned here with the preset's own
      # glyphs. .git and .config are re-pinned the same way (their preset
      # colors were cyan and orange). Other named dev dirs (node_modules,
      # .github, ...) keep their distinctive preset icons and colors.
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
        # Prepended, so these outrank the preset's own dir conds. Order matters
        # within the pair: the specific "dir & hovered" (open folder) must
        # precede plain "dir" (closed folder) or it would never match.
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
