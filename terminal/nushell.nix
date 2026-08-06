{ pkgs, config, ... }:
{
  # home-manager's gpg-agent snippet runs `$env.GPG_TTY = (tty)` unguarded;
  # without a TTY (scripts, editors spawning `nu -c` with the config loaded)
  # the external `tty` fails and silently aborts the rest of config.nu.
  # Disabled here and re-created behind an is-terminal guard in extraConfig
  # below. The SSH_AUTH_SOCK export is gated by enableSshSupport, not this
  # option, so it survives.
  services.gpg-agent.enableNushellIntegration = false;

  # Starship, fzf, zoxide, atuin and television all ship home-manager nushell
  # integrations that default to on (home.shell.enableNushellIntegration), so
  # enabling nushell here is enough to get their init sourced in config.nu.
  programs.nushell = {
    enable = true;

    settings = {
      show_banner = false;
      edit_mode = "vi";
      history = {
        max_size = 1000000;
        file_format = "sqlite";
        isolation = false;
      };
      completions.algorithm = "fuzzy";
    };

    shellAliases = {
      fm = "yazi";
      wow = "git status --untracked-files=no";
      # Unlike zsh, `ls` is NOT aliased to eza: nushell's structured ls is
      # core to its pipelines. `la` gives the eza view instead.
      la = "eza -lahF --git";
    };

    environmentVariables = {
      EDITOR = "nvim";
    };

    # Keybinding note: several integrations bind the same keys, and whoever
    # is appended last in config.nu wins. Sourcing order is television ->
    # gpg (ours, below) -> fzf -> atuin. So: atuin owns Ctrl-R (fzf's
    # history widget is disabled via FZF_CTRL_R_COMMAND="", television's
    # Ctrl-R is overridden) and fzf's file widget owns Ctrl-T (it overrides
    # television's binding) — both same as zsh. Television's smart
    # autocomplete lives on Tab-Tab instead, defined below.
    extraConfig = ''
      # zi picker: zoxide replaces FZF_DEFAULT_OPTS with _ZO_FZF_OPTS when it
      # spawns fzf, so re-seed it with the ambient opts (same as zsh).
      # Picker lines are "score path" -> {2..} is the path.
      $env._ZO_FZF_OPTS = (
        ($env.FZF_DEFAULT_OPTS? | default "")
        + " --height 40% --tmux center,70%,60% --preview-window=down --preview 'eza -1 --color=always --icons=always {2..}'"
      )

      # Run any command with an interactively-picked frecent dir as the last
      # argument: `zz nvim`, `zz eza -la`, ... (zsh's `zz`)
      def --wrapped zz [...cmd: string] {
        let picked = (zoxide query -i | complete)
        if $picked.exit_code != 0 { return }
        run-external ...$cmd ($picked.stdout | str trim)
      }

      # System generation switcher (cable channel in terminal/television.nix;
      # enter runs `nh os switch`)
      alias ng = tv nix-generations

      # Resolve a command through the nix store (zsh's `whichnix`)
      def whichnix [cmd: string] {
        readlink -f (which $cmd | get 0.path)
      }

      # Tab-Tab -> television smart autocomplete, mirroring zsh's
      # `bindkey '\t\t' tv-smart-autocomplete`. Reedline has no timed key
      # sequences, so this uses `until` semantics instead: the first Tab opens
      # the completion menu (or completes a unique match) as normal; a second
      # Tab while the menu is open launches tv. Cycle menu entries with
      # arrows / Ctrl-N / Ctrl-P instead of Tab. tv_smart_autocomplete is
      # defined by television's completion.nu, sourced later in config.nu —
      # fine, since executehostcommand resolves at keypress time.
      $env.config.keybindings = (
        $env.config.keybindings | append {
          name: tab_tab_television
          modifier: none
          keycode: tab
          mode: [emacs, vi_normal, vi_insert]
          event: {
            until: [
              { send: menu, name: completion_menu }
              { send: executehostcommand, cmd: "tv_smart_autocomplete" }
            ]
          }
        }
      )

      # TTY-guarded replacement for the gpg-agent module's nushell snippet
      # (see services.gpg-agent.enableNushellIntegration above): only wire
      # up GPG_TTY / pinentry when there actually is a terminal.
      if (is-terminal --stdin) {
        $env.GPG_TTY = (^tty)
        ${config.programs.gpg.package}/bin/gpg-connect-agent --quiet updatestartuptty /bye | ignore
      }

      # Branch from which the current branch forked (zsh's `git-parent`)
      def git-parent [] {
        git log --pretty=format:%D HEAD^
        | lines
        | where ($it =~ "origin/")
        | first
        | split row ","
        | first
        | str replace "origin/" ""
        | str trim
      }
    '';
  };
}
