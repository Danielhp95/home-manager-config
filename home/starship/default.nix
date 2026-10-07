{ lib, theme, ... }:
let
  # The palette's '#' view. The pill/slab powerline language (`open`, `close`
  # and `wedge` below) is shared with tmux's status bar.
  p = theme.hash;

  # The three powerline shapes, by code point, so that no editor or tool can
  # drop them: the round left and right caps of a pill, and the flame wedge
  # between two fills.
  glyph = hex: builtins.fromJSON ''"\u${hex}"'';
  open = glyph "e0b6";
  close = glyph "e0b4";
  wedge = glyph "e0b0";

  # A pill: `body` between the two caps, both drawn in the body's fill colour.
  pill = fill: body: "[${open}](fg:${fill})${body}[${close}](fg:${fill}) ";

  # One graphite pill per language module. The icons are real PUA glyphs:
  # grep-verify codepoints after any edit (tooling has silently dropped them).
  langPill = color: symbol: {
    format = pill "surface" "[$symbol($version)](fg:${color} bg:surface)";
    inherit symbol;
  };
  # Same pill without $version: starship only probes a version when the
  # format references it, and these probes cost a JVM start.
  langPillIconOnly = color: symbol: {
    format = pill "surface" "[$symbol](fg:${color} bg:surface)";
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
          "[${open}](fg:accent)"
          + "[ $path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[${wedge}](fg:accent bg:accent_dim)[${wedge}](fg:accent_dim bg:ash)[${wedge}](fg:ash) ";
        repo_root_format =
          "[${open}](fg:ash)"
          + "[ $before_root_path ]($before_repo_root_style)"
          + "[${wedge}](fg:ash bg:accent_dim)"
          + "[ $repo_root ]($repo_root_style)"
          + "[${wedge}](fg:accent_dim bg:accent)"
          + "[$path]($style)[$read_only]($read_only_style)[ ]($style)"
          + "[${wedge}](fg:accent bg:accent_dim)[${wedge}](fg:accent_dim bg:ash)[${wedge}](fg:ash) ";
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
        format = "[${open}](fg:surface)[$symbol](fg:accent_dim bg:surface)[$branch](fg:fg_soft bg:surface)";
        symbol = "󰊢 ";
        only_attached = true;
      };
      git_commit = {
        format = "[${open}](fg:surface)[󰜘 $hash](fg:fg_soft bg:surface)";
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
          + "[${close}](fg:surface) ";
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
        format = pill "surface" "[$symbol$state( \\($name\\))](fg:steel bg:surface)";
        symbol = "󱄅 ";
        impure_msg = "impure";
        pure_msg = "pure";
        unknown_msg = "shell";
      };
      direnv = {
        disabled = false;
        format = pill "surface" "[$symbol$loaded](fg:sage bg:surface)";
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
        format = pill "surface" "[$symbol](fg:steel bg:surface)";
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
        format = pill "surface" "[$symbol$number](fg:mauve bg:surface)";
        symbol = "󰒲 ";
        number_threshold = 1;
      };

      # Battery: hidden while healthy, gold at 30%, bold red at 15%
      battery = {
        format = pill "surface" "[$symbol$percentage]($style)";
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
        format = pill "error" "[$symbol$status( $common_meaning)( SIG$signal_name)]($style)";
        style = "bold fg:bg bg:error";
        symbol = "✘ ";
        map_symbol = false;
        recognize_signal_code = true;
      };

      cmd_duration = {
        min_time = 500;
        # fg1 not muted: this is a readout you read, and muted fails AA
        format = pill "surface" "[󱎫 $duration](fg:fg_dim bg:surface)";
      };

      # Clock — last on the line, with the same ash→accent ramp as tmux's status-right
      time = {
        disabled = false;
        format =
          "[${open}](fg:ash)[${wedge}](fg:ash bg:accent_dim)[${wedge}](fg:accent_dim bg:accent)"
          + "[󰥔 $time ](bold fg:bg bg:accent)[${close}](fg:accent)";
        time_format = "%H:%M";
      };

      # Only shown over ssh or as root; separate pills so a root prompt without
      # a hostname still closes cleanly.
      username = {
        format = pill "gold" "[$user](bold fg:bg bg:gold)";
      };
      hostname = {
        ssh_only = true;
        format = pill "gold" "[$hostname](fg:bg bg:gold)";
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
