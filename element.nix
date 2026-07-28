{ ... }:

# Element is Electron: its window frame follows GTK, but everything inside it
# is web content that only Element's own theme system can color. It reads
# ~/.config/Element/config.json at startup, and `custom_themes` there behaves
# exactly like the themes shipped in the app.
#
# NOTE the theme still has to be selected once in Settings -> Appearance
# ("Ember"). `default_theme` below only applies to a profile that has never had
# a theme chosen, since a user choice is stored in account data and wins.

let
  p = (import ./palette.nix).hash;
in
{
  xdg.configFile."Element/config.json".text = builtins.toJSON {
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
}
