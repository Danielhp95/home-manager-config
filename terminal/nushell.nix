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
      # The fzf module already fills FZF_DEFAULT_OPTS with the Ember colors;
      # append the ctrl-e "open in editor" bind from zsh on top of it.
      $env.FZF_DEFAULT_OPTS = (
        ($env.FZF_DEFAULT_OPTS? | default "")
        + " --bind='ctrl-e:execute(nvim {} > /dev/tty)+abort'"
      )

      # System generation switcher with television preview. Reads the
      # generation links from /nix/var/nix/profiles directly: `nix-env
      # --list-generations` without -p lists the *user* profile, and with
      # -p the system profile it needs root (system.lock). The selected
      # generation link is passed to `nh os switch` as a path installable
      # (`-- --switch-generation N` would hand the flag to nix build).
      def ng [] {
        let gen = (
          ls /nix/var/nix/profiles
          | where name =~ 'system-\d+-link'
          | insert num { |it| $it.name | parse --regex 'system-(?<n>\d+)-link' | get 0.n | into int }
          | sort-by -r num
          | each { |it| $"($it.num) ($it.modified | format date '%Y-%m-%d %H:%M')" }
          | to text
          | tv --preview-command "nvd diff '/nix/var/nix/profiles/system-{split: :0}-link' /nix/var/nix/profiles/system"
        )

        if ($gen | is-not-empty) {
          let num = ($gen | str trim | split row " " | first)
          nh os switch $"/nix/var/nix/profiles/system-($num)-link"
        }
      }

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
