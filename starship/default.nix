{ ... }:
let
  themes = {
    gruvbox = {
      username = "[$user]($style)";
      hostname = "[@$hostname](bold bright-red) [>](bold bright-green) ";
      directory = "[$path]($style)[$read_only]($read_only_style) ";
    };
    tokyo-night = {
      username = "[$user](bold red)";
      hostname = "[@](bold yellow)[$hostname](bold bright-cyan) [>](bold bright-green) ";
      directory = "[$path](bold bright-cyan)[$read_only](bold bright-red) ";
    };
    ember = {
      username = "[$user](fg:accent bold)";
      hostname = "[@](fg:muted)[$hostname](fg:yellow) ";
      directory = "[](fg:bg)[$path](fg:fg bg:bg)[](fg:bg bg:none)";
    };
  };
  theme = themes.ember;
in
{
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;
      palette = "ember";

      # 🔥 Ember powerline layout
      format = "$all";
      # format = ''
      #   $username$hostname$directory$git_branch$git_status
      #   $character
      # '';
      right_format = "$time";

      # 🎨 Ember palette
      palettes.ember = {
        bg = "#1e1c1a";
        fg = "#d4cfc8";
        muted = "#6e6a66";
        accent = "#ff6b4a";
        green = "#a8c686";
        yellow = "#d8a657";
        red = "#e67e80";
        blue = "#7aa2f7";
      };

      # ⏰ Time (kept from yours)
      time = {
        disabled = false;
        format = "[<$time> ⏰](fg:muted)";
        time_format = "%T";
      };

      # 👤 Username / Host (theme-driven)
      username = {
        show_always = true;
        format = theme.username;
      };

      hostname = {
        ssh_only = false;
        format = theme.hostname;
      };

      # 📁 Directory (Ember styled)
      directory = {
        format = theme.directory;
        truncation_length = 3;
        truncation_symbol = "…/";
        home_symbol = "~";
      };

      # 🌿 Git
      git_branch = {
        symbol = " ";
        style = "fg:accent";
      };

      git_status = {
        style = "fg:yellow";
        format = "([$all_status$ahead_behind]($style))";
      };

      # ⏱ Duration
      cmd_duration = {
        min_time = 500;
        format = "[took $duration](fg:muted)";
      };

      # 🧪 Languages (subtle)
      nodejs.style = "fg:green";
      python.style = "fg:green";
      rust.style = "fg:red";

      # ➜ Prompt character
      character = {
        success_symbol = "[❯](fg:accent)";
        error_symbol = "[❯](fg:red)";
      };

      # 🚨 Status (kept, Ember-ified)
      status = {
        symbol = "🎆{($status)}@";
        format = "[➜](fg:accent) [$symbol$common_meaning$signal_name$maybe_int](fg:red) ";
        map_symbol = true;
        disabled = false;
      };
    };
  };
}
