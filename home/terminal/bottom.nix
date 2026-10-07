{ theme, ... }:
let
  p = theme.hash;
in
{
  # `btm`. TextStyle keys take a table ({ color, bg_color, bold, italics }),
  # plain *_color keys a bare string; mixing them up fails at startup.
  programs.bottom = {
    enable = true;
    settings.styles = {
      widgets = {
        border_color = p.border;
        selected_border_color = p.accent;
        widget_title.color = p.accent;
        text.color = p.fg;
        selected_text = {
          color = p.bg;
          bg_color = p.accent;
        };
        disabled_text.color = p.muted;
      };
      tables.headers = {
        color = p.gold;
        bold = true;
      };
      graphs = {
        graph_color = p.border;
        legend_text.color = p.fgDim;
      };
      # Cycled per core: a short cool rotation (24 threads make a rainbow
      # unreadable); warm colours are kept for the avg/all lines.
      cpu = {
        all_entry_color = p.accent;
        avg_entry_color = p.accentBright;
        cpu_core_colors = [
          p.sage
          p.olive
          p.steel
          p.mauve
          p.sageBright
          p.oliveBright
        ];
      };
      memory = {
        ram_color = p.accent;
        cache_color = p.olive;
        swap_color = p.gold;
        arc_color = p.sage;
        gpu_colors = [ p.mauve ];
      };
      network = {
        rx_color = p.sage;
        tx_color = p.accent;
        rx_total_color = p.sageBright;
        tx_total_color = p.accentBright;
      };
      # Same ramp direction as btop's: green is fine, red needs attention.
      battery = {
        high_battery_color = p.sage;
        medium_battery_color = p.gold;
        low_battery_color = p.error;
      };
    };
  };
}
