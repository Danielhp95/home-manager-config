{ config, ... }:
let
  common = import ./common.nix;
in
{
  # home-manager's snippet runs `$env.GPG_TTY = (tty)` unguarded, which aborts
  # config.nu without a TTY (`nu -c`); a guarded copy is in extraConfig below.
  # SSH_AUTH_SOCK doesn't depend on this option.
  services.gpg-agent.enableNushellIntegration = false;

  # Starship, fzf, zoxide, atuin and tv add their nushell init by default.
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

    # `ls` stays nushell's structured ls (pipelines need it); `la` is eza.
    shellAliases.la = "eza -lahF --git";

    # Integrations bind the same keys and the last one in config.nu wins: atuin
    # gets Ctrl-R and fzf Ctrl-T, as in zsh; tv's autocomplete is on Tab-Tab.
    extraConfig = ''
      # zoxide's `zi` swaps FZF_DEFAULT_OPTS for _ZO_FZF_OPTS, so re-seed it.
      $env._ZO_FZF_OPTS = (
        ($env.FZF_DEFAULT_OPTS? | default "")
        + " ${common.zoxideFzfOpts}"
      )

      # `zz <cmd>`: run cmd on an interactively picked frecent dir, as in zsh.
      def --wrapped zz [...cmd: string] {
        let picked = (zoxide query -i | complete)
        if $picked.exit_code != 0 { return }
        run-external ...$cmd ($picked.stdout | str trim)
      }

      # Resolve a command through the nix store (zsh's `whichnix`)
      def whichnix [cmd: string] {
        readlink -f (which $cmd | get 0.path)
      }

      # Tab-Tab -> tv smart autocomplete, as in zsh. Reedline has no timed key
      # sequences: the first Tab opens the completion menu, a Tab while it is
      # open launches tv (cycle entries with the arrows or Ctrl-N/P).
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

      # The gpg-agent snippet, guarded (see enableNushellIntegration above).
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
