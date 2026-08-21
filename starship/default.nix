{ ... }:
let
  # Ember palette from the single source of truth. The tmux status bar
  # (tmux/tmux.conf) predates palette.nix and carries near-identical local
  # copies; glyph vocabulary (, 󰊢, 󰥔) and the pill/slab powerline language
  # (E0B6 open, E0B4 close, E0B0 flame-trail arrows) are shared.
  p = (import ../palette.nix).hash;

  # One quiet graphite pill per language module. Icons are nf-md where the
  # set has the language, dev/seti otherwise — real glyphs in this file, so
  # any edit here needs a codepoint grep-verify afterwards (BMP PUA glyphs
  # have been silently dropped by tooling before).
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

      # Same design as the tmux status bar: everything is a pill on the
      # transparent background, one space apart. The directory is the hot
      # coral pill with a three-step flame trail (mirrors status-left);
      # context modules sit in graphite pills so the coral stays the thing
      # your eye lands on. Line 2 is just the prompt character, so commands
      # always start at col 3.
      #
      # Everything lives on ONE line, with no right_format, because starship's
      # zsh init renders the two halves in two SEPARATE processes: it sets both
      # PROMPT and RPROMPT to `$(starship prompt …)` command substitutions, so a
      # right prompt costs a second fork+exec of starship on every single
      # prompt draw — measured at 3.3ms of the ~29ms it takes to get a new
      # prompt back after Enter. One line, one process.
      #
      # Reading order is cool -> hot and back: the directory pill opens full
      # coral and ramps down to ash, then the readouts sit in graphite, then
      # the clock ramps ash -> coral again and caps round. Same bookending as
      # the tmux status bar, where the session and the clock are the two hot
      # ends. The clock is last so it lands as close to the right as the
      # content allows, which is where the eye already looks for it.
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
        fg0 = p.fg;
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

      # Directory — the campfire pill with the flame trail off the back.
      # Inside a repo the pill heats along the full tmux ramp, hotter the
      # deeper you are: ash parent path → banked repo root → coral path
      # inside the repo. Outside a repo the whole pill burns full coral.
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

      # Git — one graphite pill: banked-coral icon, plain branch, gold
      # status, mauve while a rebase/merge is in flight. The pill opens in
      # git_branch and closes in git_status so the middle segments can come
      # and go without breaking the shape.
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
        # Counts with meaning-bearing glyphs instead of punctuation:
        # 󰈸 modified  󰄬 staged  󰐕 untracked  󰆴 deleted  󰑕 renamed
        # 󰅖 conflicted  󰆓 stashed  󰅧/󰅢 commits to push / to pull
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

      # Nix develop/shell indicator — steel-on-graphite pill, invaluable in
      # this repo
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

      # Nix project outside a shell — flake/shell/default.nix or any .nix
      # file. Detection-only custom module: no command, so no fork per
      # prompt (measured <1ms). Same steel snowflake as nix_shell; inside
      # `nix develop` both show, and the shell pill carries the state.
      custom.nix = {
        detect_files = [ "flake.nix" "shell.nix" "default.nix" ];
        detect_extensions = [ "nix" ];
        symbol = "󱄅 ";
        format = "[](fg:bg1)[$symbol](fg:steel bg:bg1)[](fg:bg1) ";
      };

      # Languages — quiet graphite pills, icon-first; they're context, not
      # heroes. One module per detected project, so the roster can be wide
      # without the prompt ever growing. JVM languages are icon-only (see
      # langPillIconOnly).
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

      # Background jobs — small mauve pill. (No sudo pill: the
      # module's `sudo -n` check costs ~18ms on every prompt draw.)
      jobs = {
        format = "[](fg:bg1)[$symbol$number](fg:mauve bg:bg1)[](fg:bg1) ";
        symbol = "󰒲 ";
        number_threshold = 1;
      };

      # Battery — a pill that cools olive → gold → red as it drains
      battery = {
        format = "[](fg:bg1)[$symbol$percentage]($style)[](fg:bg1) ";
        full_symbol = "󰁹 ";
        charging_symbol = "󰂄 ";
        discharging_symbol = "󰁾 ";
        unknown_symbol = "󰂑 ";
        empty_symbol = "󰂎 ";
        # hidden while healthy — appears gold at 30%, bold red at 15%
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

      # Clock — the hot end of the ramp, capped round, same ash→ember ramp
      # as tmux's status-right. Last module on the line: it closes the prompt
      # the way the clock closes the tmux bar.
      time = {
        disabled = false;
        format =
          "[](fg:ash)[](fg:ash bg:ember_dim)[](fg:ember_dim bg:ember)"
          + "[󰥔 $time ](bold fg:bg0 bg:ember)[](fg:ember)";
        time_format = "%H:%M";
      };

      # Only interesting over ssh or as root — local prompts stay clean.
      # Each is its own gold pill so a root prompt without a hostname still
      # closes cleanly.
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
