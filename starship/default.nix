{ ... }:
let
  # Ember palette from the single source of truth. The tmux status bar
  # (tmux/tmux.conf) predates palette.nix and carries near-identical local
  # copies; glyph vocabulary (, 󰊢, 󰥔) and the pill/slab powerline language
  # (E0B6 open, E0B4 close, E0B0 flame-trail arrows) are shared.
  p = (import ../palette.nix).hash;
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
      format =
        "$username$hostname"
        + "$directory"
        + "$git_branch$git_commit$git_state$git_status"
        + "$nix_shell$direnv"
        + "$python$nodejs$rust$lua"
        + "$status"
        + "\n$character";

      right_format = "$jobs$battery$cmd_duration$time";

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

      # Languages — quiet graphite pills, icon-first; they're context, not
      # heroes
      python = {
        format = "[](fg:bg1)[$symbol($version)](fg:sage bg:bg1)[](fg:bg1) ";
        symbol = " ";
      };
      nodejs = {
        format = "[](fg:bg1)[$symbol($version)](fg:olive bg:bg1)[](fg:bg1) ";
        symbol = " ";
      };
      rust = {
        format = "[](fg:bg1)[$symbol($version)](fg:mauve bg:bg1)[](fg:bg1) ";
        symbol = " ";
      };
      lua = {
        format = "[](fg:bg1)[$symbol($version)](fg:steel bg:bg1)[](fg:bg1) ";
        symbol = " ";
      };

      # Background jobs — small mauve pill on the right. (No sudo pill: the
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
      # as tmux's status-right
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
