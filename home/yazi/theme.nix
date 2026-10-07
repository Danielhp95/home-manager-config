# yazi's theme, from the palette's '#' view. yazi silently ignores unknown
# theme keys, so a typo or renamed key just reverts to the preset (v26 moved
# the hover styles from [mgr] to [indicator]): docs/upgrade-checklist.md. No
# [app].overall bg: the terminal paints it.
{ lib, p }:
{
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

  # First match wins; `is` conditions go before the broad mime globs. The
  # colour of each kind is ../terminal/file-kinds.nix, shared with LS_COLORS.
  filetype.rules =
    let
      kinds = import ../terminal/file-kinds.nix;
      rule =
        kind: match:
        match
        // {
          fg = p.${kinds.${kind}.slot};
        }
        // lib.optionalAttrs (kinds.${kind}.bold or false) { bold = true; }
        // lib.optionalAttrs (kinds.${kind}.strike or false) { crossed = true; };
    in
    [
      (rule "dir" { url = "*/"; })
      (rule "orphan" {
        is = "orphan";
        url = "*";
      })
      (rule "link" {
        is = "link";
        url = "*";
      })
      (rule "exec" {
        is = "exec";
        url = "*";
      })
      (rule "image" { mime = "image/*"; })
      (rule "media" { mime = "{audio,video}/*"; })
      (rule "archive" {
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
      })
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
}
