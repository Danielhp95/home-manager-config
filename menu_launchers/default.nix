{ pkgs, ... }:

{
  # rofi is gone, along with its spotlight_dark.rasi theme, the
  # rofi-file-browser plugin and papirus-icon-theme (which existed only to feed
  # rofi's icon-theme; GTK icons are MoreWaita, see hyprland/theming.nix).
  #
  # Everything it was still doing was dmenu-style list selection, and vicinae —
  # already running as a session daemon below, already wearing the Ember theme —
  # does that with `vicinae dmenu`. See scripts/open_paper.sh and
  # scripts/choose_bluetooth_device_from_paired.sh. One toolkit fewer, and the
  # menus now match everything else on screen.
  #
  # Behaviour note for anything else migrated later: vicinae dmenu writes the
  # chosen line to stdout and exits 0 — and it also exits 0 when dismissed with
  # nothing chosen. Test the output, never the exit status.
  home.packages = with pkgs; [
      poppler-utils # pdftoppm: renders paper thumbnails for open_paper.sh's quick-look preview
  ];
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = {
        dark = {
          name = "ember";
          icon_theme = "auto";
        };
        light = {
          name = "ember-light";
          icon_theme = "auto";
        };
      };
      launcher_window = {
        size = {
          width = 1536;
          height = 864;
        };
      };
      font = {
        normal = {
          size = 15;
          # The installed package is nerd-fonts.jetbrains-mono, whose family name
          # is "JetBrainsMono Nerd Font" (no space after "JetBrains") — a plain or
          # misspelled family doesn't resolve and fc-match falls back to a CJK
          # font. Check with: fc-match "JetBrainsMono Nerd Font"
          family = "JetBrainsMono Nerd Font";
        };
      };
    };
    themes = {
      ember = {
        meta = {
          version = 1;
          name = "Ember";
          description = "Warm graphite monochrome with a single coral spark";
          variant = "dark";
          icon = "icons/ember.png";
          inherits = "vicinae-dark";
        };

        colors = {
          core = {
            background = "#1c1b19";
            foreground = "#d8d0c0";
            secondary_background = "#242320";
            border = "#3a342d";
            accent = "#e08060";
          };

          accents = {
            blue = "#ef7f38"; # steel (magma orange since 2026-08)
            green = "#8a9868"; # olive
            magenta = "#988090"; # mauve
            orange = "#c09058";
            purple = "#988090";
            red = "#e08060"; # coral
            yellow = "#c8b468"; # gold
            cyan = "#7aa88a"; # sage
          };
        };
      };

      ember-light = {
        meta = {
          version = 1;
          name = "Ember Light";
          description = "Soft parchment tones with restrained earthy accents";
          variant = "light";
          icon = "icons/ember-light.png";
          inherits = "vicinae-light";
        };

        colors = {
          core = {
            background = "#e6dac4";
            foreground = "#282418";
            secondary_background = "#d8ccb6";
            border = "#b8ac96";
            accent = "#b84c30";
          };

          accents = {
            blue = "#a84e16"; # steel (light-mode magma since 2026-08)
            green = "#4a6830"; # olive
            magenta = "#706070"; # mauve
            orange = "#946030";
            purple = "#706070";
            red = "#b84c30"; # coral
            yellow = "#7a6820"; # gold
            cyan = "#386858"; # sage
          };
        };
      };
    };
  };

}
