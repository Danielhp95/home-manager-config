{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    font = "Fira Code 30";
    extraConfig = {
      width = 100;
      lines = 10;
      columns = 1;
      icon-theme = "Papirus-Dark";
      bw = 7;
      location = 0;
      padding = 5;
      yoffset = 0;
      xoffset = 0;
      fixed-num-lines = true;
      show-icons = true;
      ssh-client = "ssh";
      ssh-command = "{terminal} -e {ssh-client} {host}";
      run-command = "{cmd}";
      parse-hosts = true;
      matching = "fuzzy";
      separator-style = "none";
      scrollbar-width = 0;
      kb-mode-next = "Shift+Right,Control+Tab";
      kb-mode-previous = "Shift+Left,Control+Shift+Tab,Alt+h";
      kb-row-up = "Up,Control+p,Shift+Tab,Shift+ISO_Left_Tab,Alt+k";
      kb-row-down = "Down,Control+n,Alt+j";
    };
    theme = ./rofi/spotlight_dark.rasi; # Personal theme
    # theme = "~/.cache/wal/colors-rofi-dark.rasi";
    terminal = "xterm-kitty";
    plugins = with pkgs; [
      rofi-file-browser
      pywal
    ];
  };
  home.packages = with pkgs; [
    papirus-icon-theme
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
          # The installed package is nerd-fonts.iosevka, whose family name is
          # "Iosevka Nerd Font" — plain "Iosevka" doesn't resolve and fc-match
          # falls back to a CJK font.
          family = "Iosevka Nerd Font";
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
            blue = "#7890a0"; # steel
            green = "#8a9868"; # olive
            magenta = "#988090"; # mauve
            orange = "#c09058";
            purple = "#988090";
            red = "#e08060"; # coral
            yellow = "#c8b468"; # gold
            cyan = "#80a090"; # sage
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
            blue = "#3a6080"; # steel
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
