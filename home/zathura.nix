{ theme, ... }:
let
  p = theme.hash;
in
{
  programs.zathura = {
    enable = true;

    options = {
      # ── Colours, from the palette ──
      default-bg = p.bg;
      default-fg = p.fg;

      statusbar-bg = p.bgAlt;
      statusbar-fg = p.fg;
      inputbar-bg = p.bgAlt;
      inputbar-fg = p.fg;

      completion-bg = p.bgAlt;
      completion-fg = p.fg;
      completion-group-bg = p.bgDeep;
      completion-group-fg = p.fgDim;
      completion-highlight-bg = p.accent;
      completion-highlight-fg = p.bg;

      notification-bg = p.bgAlt;
      notification-fg = p.fg;
      notification-warning-bg = p.gold;
      notification-warning-fg = p.bg;
      notification-error-bg = p.error;
      notification-error-fg = p.bg;

      # Search hits: gold, with the current hit in the accent.
      highlight-color = p.gold;
      highlight-active-color = p.accent;

      index-bg = p.bg;
      index-fg = p.fg;
      index-active-bg = p.accent;
      index-active-fg = p.bg;

      render-loading-bg = p.bg;
      render-loading-fg = p.fgDim;

      # Dark-mode rendering of the document itself.
      recolor = true;
      recolor-lightcolor = p.bg;
      recolor-darkcolor = p.fg;
      recolor-reverse-video = true;
      recolor-keephue = true;

      # ── Behaviour ──
      font = "monospace normal 20";
      pages-per-row = 1;
      # Stop at page boundaries.
      scroll-page-aware = true;
      scroll-full-overlap = "0.08";
      adjust-open = "width";
      continuous-hist-save = true;
      window-title-basename = true;
      selection-clipboard = "clipboard";
    };

    mappings = {
      "<C-h>" = "set recolor-keephue toggle";
      b = "toggle_statusbar";
      "[normal] p" = "toggle_presentation";
    };
  };
}
