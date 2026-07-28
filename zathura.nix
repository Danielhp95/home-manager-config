{ ... }:

let
  p = (import ./palette.nix).hash;
in
{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      # Colors come from ./palette.nix (Ember / WhiteSur-Dark-orange family).
      set default-bg "${p.bg}"
      set default-fg "${p.fg}"

      set statusbar-bg "${p.bgAlt}"
      set statusbar-fg "${p.fg}"
      set inputbar-bg "${p.bgAlt}"
      set inputbar-fg "${p.fg}"

      set completion-bg "${p.bgAlt}"
      set completion-fg "${p.fg}"
      set completion-group-bg "${p.bgDeep}"
      set completion-group-fg "${p.fgDim}"
      set completion-highlight-bg "${p.accent}"
      set completion-highlight-fg "${p.bg}"

      set notification-bg "${p.bgAlt}"
      set notification-fg "${p.fg}"
      set notification-warning-bg "${p.gold}"
      set notification-warning-fg "${p.bg}"
      set notification-error-bg "${p.error}"
      set notification-error-fg "${p.bg}"

      # Search hits: gold, with the current hit in coral.
      set highlight-color "${p.gold}"
      set highlight-active-color "${p.accent}"

      set index-bg "${p.bg}"
      set index-fg "${p.fg}"
      set index-active-bg "${p.accent}"
      set index-active-fg "${p.bg}"

      set render-loading-bg "${p.bg}"
      set render-loading-fg "${p.fgDim}"

      # Dark-mode rendering of the document itself.
      set recolor true
      set recolor-lightcolor "${p.bg}"
      set recolor-darkcolor "${p.fg}"
      set recolor-reverse-video "true"
      set recolor-keephue "true"

      set font "monospace normal 20"
      map <C-h> set recolor-keephue toggle

      map b toggle_statusbar
      # One page per row by default
      set pages-per-row 1

      # stop at page boundaries
      set scroll-page-aware "true"
      set scroll-full-overlap 0.08

      set adjust-open "width"

      set continuous-hist-save "true"

      set window-title-basename "true"
      # Copies selection to system clipboard
      set selection-clipboard "clipboard"

      map [normal] p toggle_presentation
    '';
  };
}
