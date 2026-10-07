{ lib, theme, ... }:
let
  # The palette's '#' view. The pill/slab powerline language (E0B6
  # open, E0B4 close, E0B0 flame trail) is shared with tmux's status bar.
  p = theme.hash;

  # One graphite pill per language module. The icons are real PUA glyphs:
  # grep-verify codepoints after any edit (tooling has silently dropped them).
  langPill = color: symbol: {
    format = "[](fg:surface)[$symbol($version)](fg:${color} bg:surface)[](fg:surface) ";
    inherit symbol;
  };
  # Same pill without $version: starship only probes a version when the
  # format references it, and these probes cost a JVM start.
  langPillIconOnly = color: symbol: {
    format = "[](fg:surface)[$symbol](fg:${color} bg:surface)[](fg:surface) ";
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
      palette = "theme";

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

      # Every slot under its own name, in snake_case: starship lower-cases the
      # colour names it reads, so `accentDim` would never be found.
      palettes.theme = lib.mapAttrs' (
        slot: lib.nameValuePair (builtins.replaceStrings [ "-" ] [ "_" ] (theme.colour.toKebab slot))
      ) p.slots;

      # Directory: in a repo the pill heats ash (parent path) → accent_dim (repo
      # root) → coral (path inside); elsewhere it is all coral.
      directory = {
        format =
          "[](fg:accent)"
          + "[ $path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[](fg:accent bg:accent_dim)[](fg:accent_dim bg:ash)[](fg:ash) ";
        repo_root_format =
          "[](fg:ash)"
          + "[ $before_root_path ]($before_repo_root_style)"
          + "[](fg:ash bg:accent_dim)"
          + "[ $repo_root ]($repo_root_style)"
          + "[](fg:accent_dim bg:accent)"
          + "[$path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[](fg:accent bg:accent_dim)[](fg:accent_dim bg:ash)[](fg:ash) ";
        style = "bold fg:bg bg:accent";
        before_repo_root_style = "bold fg:bg bg:ash";
        repo_root_style = "bold fg:bg bg:accent_dim";
        read_only = " 󰌾";
        read_only_style = "bold fg:bg bg:accent";
        truncation_length = 3;
        truncation_symbol = "…/";
        home_symbol = "~";
      };

      # Git — one graphite pill that opens in git_branch and closes in
      # git_status, so the segments between can come and go.
      git_branch = {
        format = "[](fg:surface)[$symbol](fg:accent_dim bg:surface)[$branch](fg:fg_soft bg:surface)";
        symbol = "󰊢 ";
        only_attached = true;
      };
      git_commit = {
        format = "[](fg:surface)[󰜘 $hash](fg:fg_soft bg:surface)";
        only_detached = true;
      };
      git_state = {
        format = "[ $state( $progress_current/$progress_total)](fg:mauve bg:surface)";
      };
      git_status = {
        format =
          "([ ](bg:surface)"
          + "[$conflicted](fg:error bg:surface)[$deleted](fg:error bg:surface)"
          + "[$renamed](fg:mauve bg:surface)[$modified](fg:gold bg:surface)"
          + "[$staged](fg:sage bg:surface)[$untracked](fg:fg_dim bg:surface)"
          + "[$stashed](fg:steel bg:surface)[$ahead_behind](fg:accent_bright bg:surface))"
          + "[](fg:surface) ";
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
        format = "[](fg:surface)[$symbol$state( \\($name\\))](fg:steel bg:surface)[](fg:surface) ";
        symbol = "󱄅 ";
        impure_msg = "impure";
        pure_msg = "pure";
        unknown_msg = "shell";
      };
      direnv = {
        disabled = false;
        format = "[](fg:surface)[$symbol$loaded](fg:sage bg:surface)[](fg:surface) ";
        symbol = "󰌪 ";
        loaded_msg = "env";
        unloaded_msg = "env✗";
      };

      # Nix project outside a shell. Detection-only (no command, so no fork per
      # prompt); inside `nix develop` both pills show.
      custom.nix = {
        detect_files = [
          "flake.nix"
          "shell.nix"
          "default.nix"
        ];
        detect_extensions = [ "nix" ];
        symbol = "󱄅 ";
        format = "[](fg:surface)[$symbol](fg:steel bg:surface)[](fg:surface) ";
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
      ruby = langPill "accent_dim" "󰴭 ";
      swift = langPill "steel" "󰛥 ";
      dart = langPill "sage" " ";
      scala = langPillIconOnly "accent_dim" " ";
      elixir = langPill "mauve" " ";
      haskell = langPill "mauve" "󰲒 ";
      julia = langPill "sage" " ";
      zig = langPill "gold" " ";

      # No sudo pill: the module's `sudo -n` check costs ~18ms per prompt.
      jobs = {
        format = "[](fg:surface)[$symbol$number](fg:mauve bg:surface)[](fg:surface) ";
        symbol = "󰒲 ";
        number_threshold = 1;
      };

      # Battery: hidden while healthy, gold at 30%, bold red at 15%
      battery = {
        format = "[](fg:surface)[$symbol$percentage]($style)[](fg:surface) ";
        full_symbol = "󰁹 ";
        charging_symbol = "󰂄 ";
        discharging_symbol = "󰁾 ";
        unknown_symbol = "󰂑 ";
        empty_symbol = "󰂎 ";
        display = [
          {
            threshold = 15;
            style = "bold fg:error bg:surface";
          }
          {
            threshold = 30;
            style = "fg:gold bg:surface";
          }
        ];
      };

      # Non-zero exit — the one red pill; bold dark-on-red like the hot slabs
      status = {
        disabled = false;
        format = "[](fg:error)[$symbol$status( $common_meaning)( SIG$signal_name)]($style)[](fg:error) ";
        style = "bold fg:bg bg:error";
        symbol = "✘ ";
        map_symbol = false;
        recognize_signal_code = true;
      };

      cmd_duration = {
        min_time = 500;
        # fg1 not muted: this is a readout you read, and muted fails AA
        format = "[](fg:surface)[󱎫 $duration](fg:fg_dim bg:surface)[](fg:surface) ";
      };

      # Clock — last on the line, with the same ash→accent ramp as tmux's status-right
      time = {
        disabled = false;
        format =
          "[](fg:ash)[](fg:ash bg:accent_dim)[](fg:accent_dim bg:accent)"
          + "[󰥔 $time ](bold fg:bg bg:accent)[](fg:accent)";
        time_format = "%H:%M";
      };

      # Only shown over ssh or as root; separate pills so a root prompt without
      # a hostname still closes cleanly.
      username = {
        format = "[](fg:gold)[$user](bold fg:bg bg:gold)[](fg:gold) ";
      };
      hostname = {
        ssh_only = true;
        format = "[](fg:gold)[$hostname](fg:bg bg:gold)[](fg:gold) ";
      };

      character = {
        success_symbol = "[❯](bold fg:accent)";
        error_symbol = "[❯](bold fg:error)";
        vimcmd_symbol = "[❮](bold fg:steel)";
      };
      continuation_prompt = "[··](fg:muted) ";
    };
  };
}
