_:

# Only Element's own theme system colours its web content, via `custom_themes`.
# `default_theme` only applies to a profile that never chose a theme (the choice
# lives in account data), so the theme is picked once by hand:
# docs/manual-steps.md.

let
  p = (import ../palette).hash;
in
{
  programs.element-desktop = {
    enable = true;
    settings = {
      default_theme = "custom-Ember";

      setting_defaults.custom_themes = [
        {
          name = "Ember";
          is_dark = true;
          colors = {
            accent-color = p.accent;
            primary-color = p.accent;
            warning-color = p.error;

            sidebar-color = p.bgDeep;
            roomlist-background-color = p.bg;
            roomlist-text-color = p.fg;
            roomlist-text-secondary-color = p.fgDim;
            roomlist-highlights-color = p.surface;
            roomlist-separator-color = p.border;

            timeline-background-color = p.bg;
            timeline-text-color = p.fg;
            timeline-text-secondary-color = p.fgDim;
            timeline-highlights-color = p.bgAlt;

            secondary-content = p.fgDim;
            tertiary-content = p.muted;

            reaction-row-button-selected-bg-color = p.surface;
            menu-selected-color = p.surface;
            focus-bg-color = p.surface;
            room-highlight-color = p.surface;
            togglesw-off-color = p.border;
            other-user-pill-bg-color = p.border;
          };
        }
      ];
    };
  };
}
