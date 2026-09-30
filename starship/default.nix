{ ... }:
let
  # Ember palette from palette.nix. The pill/slab powerline language (E0B6
  # open, E0B4 close, E0B0 flame trail) is shared with tmux's status bar.
  p = (import ../palette.nix).hash;

  # One graphite pill per language module. The icons are real PUA glyphs:
  # grep-verify codepoints after any edit (tooling has silently dropped them).
  langPill = color: symbol: {
    format = "[](fg:bg1)[$symbol($version)](fg:${color} bg:bg1)[](fg:bg1) ";
    inherit symbol;
  };
  # Same pill without $version: starship only probes a version when the
  # format references it, and these probes cost a JVM start.
  langPillIconOnly = color: symbol: {
    format = "[](fg:bg1)[$symbol](fg:${color} bg:bg1)[](fg:bg1) ";
    inherit symbol;
  };
in
{
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;
      # Hard cap on any single module's command (git_status in a huge repo,
      # a slow language probe): the prompt can degrade but never hang.
      command_timeout = 500;
      palette = "ember";

      # Same pills as the tmux bar: the directory is the hot coral pill with a
      # flame trail, context sits in graphite, the clock ramps back to coral.
      # One line and no right_format: zsh would render RPROMPT with a second
      # starship fork per prompt (see ../zsh/default.nix).
      format =
        "$username$hostname"
        + "$directory"
        + "$git_branch$git_commit$git_state$git_status"
        + "$nix_shell$direnv\${custom.nix}"
        + "$python$nodejs$rust$lua$golang$java$kotlin$c$cpp$dotnet"
        + "$php$ruby$swift$dart$scala$elixir$haskell$julia$zig"
        + "$status"
        + "$cmd_duration$jobs$battery$time"
        + "\n$character";

      palettes.ember = {
        bg0 = p.bg;
        bg1 = p.surface;
        fg1 = p.fgDim;
        fg_soft = p.fgSoft;
        muted = p.muted;
        ember = p.accent;
        ember_dim = p.accentDim;
        ember_hot = p.accentBright;
        ash = p.ash;
        gold = p.gold;
        olive = p.olive;
        steel = p.steel;
        sage = p.sage;
        mauve = p.mauve;
        error = p.error;
      };

      # Directory: in a repo the pill heats ash (parent path) → ember_dim (repo
      # root) → coral (path inside); elsewhere it is all coral.
      directory = {
        format =
          "[](fg:ember)"
          + "[ $path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[](fg:ember bg:ember_dim)[](fg:ember_dim bg:ash)[](fg:ash) ";
        repo_root_format =
          "[](fg:ash)"
          + "[ $before_root_path ]($before_repo_root_style)"
          + "[](fg:ash bg:ember_dim)"
          + "[ $repo_root ]($repo_root_style)"
          + "[](fg:ember_dim bg:ember)"
          + "[$path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[](fg:ember bg:ember_dim)[](fg:ember_dim bg:ash)[](fg:ash) ";
        style = "bold fg:bg0 bg:ember";
        before_repo_root_style = "bold fg:bg0 bg:ash";
        repo_root_style = "bold fg:bg0 bg:ember_dim";
        read_only = " 󰌾";
        read_only_style = "bold fg:bg0 bg:ember";
        truncation_length = 3;
        truncation_symbol = "…/";
        home_symbol = "~";
      };

      # Git — one graphite pill that opens in git_branch and closes in
      # git_status, so the segments between can come and go.
      git_branch = {
        format = "[](fg:bg1)[$symbol](fg:ember_dim bg:bg1)[$branch](fg:fg_soft bg:bg1)";
        symbol = "󰊢 ";
        only_attached = true;
      };
      git_commit = {
        format = "[](fg:bg1)[󰜘 $hash](fg:fg_soft bg:bg1)";
        only_detached = true;
      };
      git_state = {
        format = "[ $state( $progress_current/$progress_total)](fg:mauve bg:bg1)";
      };
      git_status = {
        format =
          "([ ](bg:bg1)"
          + "[$conflicted](fg:error bg:bg1)[$deleted](fg:error bg:bg1)"
          + "[$renamed](fg:mauve bg:bg1)[$modified](fg:gold bg:bg1)"
          + "[$staged](fg:sage bg:bg1)[$untracked](fg:fg1 bg:bg1)"
          + "[$stashed](fg:steel bg:bg1)[$ahead_behind](fg:ember_hot bg:bg1))"
          + "[](fg:bg1) ";
        conflicted = "󰅖\${count} ";
        deleted = "󰆴\${count} ";
        renamed = "󰑕\${count} ";
        modified = "󰈸\${count} ";
        staged = "󰄬\${count} ";
        untracked = "󰐕\${count} ";
        stashed = "󰆓\${count} ";
        ahead = "󰅧\${count} ";
        behind = "󰅢\${count} ";
        diverged = "󰅧\${ahead_count} 󰅢\${behind_count} ";
      };

      # Nix develop/shell indicator
      nix_shell = {
        format = "[](fg:bg1)[$symbol$state( \\($name\\))](fg:steel bg:bg1)[](fg:bg1) ";
        symbol = "󱄅 ";
        impure_msg = "impure";
        pure_msg = "pure";
        unknown_msg = "shell";
      };
      direnv = {
        disabled = false;
        format = "[](fg:bg1)[$symbol$loaded](fg:sage bg:bg1)[](fg:bg1) ";
        symbol = "󰌪 ";
        loaded_msg = "env";
        unloaded_msg = "env✗";
      };

      # Nix project outside a shell. Detection-only (no command, so no fork per
      # prompt); inside `nix develop` both pills show.
      custom.nix = {
        detect_files = [ "flake.nix" "shell.nix" "default.nix" ];
        detect_extensions = [ "nix" ];
        symbol = "󱄅 ";
        format = "[](fg:bg1)[$symbol](fg:steel bg:bg1)[](fg:bg1) ";
      };

      # Languages; JVM ones are icon-only (see langPillIconOnly)
      python = langPill "sage" "󰌠 ";
      nodejs = langPill "olive" "󰎙 ";
      rust = langPill "mauve" "󱘗 ";
      lua = langPill "steel" "󰢱 ";
      golang = langPill "sage" "󰟓 ";
      java = langPillIconOnly "gold" "󰬷 ";
      kotlin = langPillIconOnly "mauve" "󱈙 ";
      c = langPill "olive" "󰙱 ";
      cpp = langPill "olive" "󰙲 ";
      dotnet = langPill "mauve" "󰌛 ";
      php = langPill "mauve" "󰌟 ";
      ruby = langPill "ember_dim" "󰴭 ";
      swift = langPill "steel" "󰛥 ";
      dart = langPill "sage" " ";
      scala = langPillIconOnly "ember_dim" " ";
      elixir = langPill "mauve" " ";
      haskell = langPill "mauve" "󰲒 ";
      julia = langPill "sage" " ";
      zig = langPill "gold" " ";

      # No sudo pill: the module's `sudo -n` check costs ~18ms per prompt.
      jobs = {
        format = "[](fg:bg1)[$symbol$number](fg:mauve bg:bg1)[](fg:bg1) ";
        symbol = "󰒲 ";
        number_threshold = 1;
      };

      # Battery: hidden while healthy, gold at 30%, bold red at 15%
      battery = {
        format = "[](fg:bg1)[$symbol$percentage]($style)[](fg:bg1) ";
        full_symbol = "󰁹 ";
        charging_symbol = "󰂄 ";
        discharging_symbol = "󰁾 ";
        unknown_symbol = "󰂑 ";
        empty_symbol = "󰂎 ";
        display = [
          { threshold = 15; style = "bold fg:error bg:bg1"; }
          { threshold = 30; style = "fg:gold bg:bg1"; }
        ];
      };

      # Non-zero exit — the one red pill; bold dark-on-red like the hot slabs
      status = {
        disabled = false;
        format = "[](fg:error)[$symbol$status( $common_meaning)( SIG$signal_name)]($style)[](fg:error) ";
        style = "bold fg:bg0 bg:error";
        symbol = "✘ ";
        map_symbol = false;
        recognize_signal_code = true;
      };

      cmd_duration = {
        min_time = 500;
        # fg1 not muted: this is a readout you read, and muted fails AA
        format = "[](fg:bg1)[󱎫 $duration](fg:fg1 bg:bg1)[](fg:bg1) ";
      };

      # Clock — last on the line, with the same ash→ember ramp as tmux's status-right
      time = {
        disabled = false;
        format =
          "[](fg:ash)[](fg:ash bg:ember_dim)[](fg:ember_dim bg:ember)"
          + "[󰥔 $time ](bold fg:bg0 bg:ember)[](fg:ember)";
        time_format = "%H:%M";
      };

      # Only shown over ssh or as root; separate pills so a root prompt without
      # a hostname still closes cleanly.
      username = {
        format = "[](fg:gold)[$user](bold fg:bg0 bg:gold)[](fg:gold) ";
      };
      hostname = {
        ssh_only = true;
        format = "[](fg:gold)[$hostname](fg:bg0 bg:gold)[](fg:gold) ";
      };

      character = {
        success_symbol = "[❯](bold fg:ember)";
        error_symbol = "[❯](bold fg:error)";
        vimcmd_symbol = "[❮](bold fg:steel)";
      };
      continuation_prompt = "[··](fg:muted) ";
    };
  };
}
