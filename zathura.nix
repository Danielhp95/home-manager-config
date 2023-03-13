{ ... }:

{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set default-bg "#1d1f21"
      set default-fg "#e0e0e0"
      set completion-group-bg "#1d1f21"
      set recolor true
      set recolor-lightcolor "#1d1f21"
      set recolor-darkcolor "#e0e0e0"
      set recolor-reverse-video "true"
      set recolor-keephue "true"
      set statusbar-bg "#282a2e"
      set statusbar-fg "#e0e0e0"
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
