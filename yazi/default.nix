{
  pkgs,
  lib,
  ...
}:
let
  p = (import ../palette.nix).hash;

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

      help = {
        on.fg = p.accent;
        run.fg = p.sage;
        desc.fg = p.fgDim;
        hovered = {
          bg = p.surface;
          bold = true;
        };
        footer.fg = p.fgDim;
      };

      # First match wins; `is` conditions go before the broad mime globs.
      filetype.rules = [
        {
          url = "*/";
          fg = p.steel;
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
      # glyphs. Named dev dirs (.git, .config, node_modules, ...) keep their
      # distinctive preset icons and colors on purpose.
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
