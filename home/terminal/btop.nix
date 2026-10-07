{ pkgs, theme, ... }:
let
  p = theme.hash;
in
{
  programs.btop = {
    package = pkgs.btop-cuda;
    enable = true;
    settings = {
      shown_boxes = "cpu proc";
      vim_keys = true;
      rounded_corners = true;
      # themes.ember below; btop can't follow the terminal palette.
      color_theme = "ember";
      # The theme's gradients are 24-bit; without this btop quantises them.
      truecolor = true;
    };
    # Gradients run calm -> hot (sage -> gold -> error) where a high reading
    # is bad, and the other way for free/available.
    themes.ember = ''
      theme[main_bg]="${p.bg}"
      theme[main_fg]="${p.fg}"
      theme[title]="${p.accent}"
      theme[hi_fg]="${p.accentBright}"
      theme[selected_bg]="${p.surface}"
      theme[selected_fg]="${p.accentBright}"
      theme[inactive_fg]="${p.muted}"
      theme[graph_text]="${p.fgDim}"
      theme[meter_bg]="${p.border}"
      theme[proc_misc]="${p.olive}"
      theme[cpu_box]="${p.border}"
      theme[mem_box]="${p.border}"
      theme[net_box]="${p.border}"
      theme[proc_box]="${p.border}"
      theme[div_line]="${p.divider}"

      theme[temp_start]="${p.sage}"
      theme[temp_mid]="${p.gold}"
      theme[temp_end]="${p.error}"
      theme[cpu_start]="${p.sage}"
      theme[cpu_mid]="${p.gold}"
      theme[cpu_end]="${p.error}"
      theme[process_start]="${p.sage}"
      theme[process_mid]="${p.gold}"
      theme[process_end]="${p.error}"

      theme[used_start]="${p.sage}"
      theme[used_mid]="${p.gold}"
      theme[used_end]="${p.error}"
      theme[free_start]="${p.error}"
      theme[free_mid]="${p.gold}"
      theme[free_end]="${p.sage}"
      theme[available_start]="${p.error}"
      theme[available_mid]="${p.gold}"
      theme[available_end]="${p.sage}"
      theme[cached_start]="${p.olive}"
      theme[cached_mid]="${p.sage}"
      theme[cached_end]="${p.sageBright}"

      theme[download_start]="${p.olive}"
      theme[download_mid]="${p.sage}"
      theme[download_end]="${p.sageBright}"
      theme[upload_start]="${p.accentDim}"
      theme[upload_mid]="${p.accent}"
      theme[upload_end]="${p.accentBright}"

      theme[followed_bg]="${p.accent}"
      theme[followed_fg]="${p.bg}"
      theme[proc_follow_bg]="${p.accent}"
      theme[proc_pause_bg]="${p.gold}"
      theme[proc_banner_bg]="${p.surface}"
      theme[proc_banner_fg]="${p.fg}"
    '';
  };
}
