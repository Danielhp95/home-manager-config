{ pkgs, lib, config, ... }:
let
  keyBindings = builtins.readFile ./key-bindings.zsh;
  fzf-tab-conf = ''
    zstyle ":completion:*:git-checkout:*" sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':completion:*' list-colors ${"\${(s.:.)LS_COLORS}"}

    # Completions for specific programs
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
  '';
  fileManager = "yazi";
in
{
  home.packages = with pkgs; [
    fd # find alternative
    dust # du alternative. Pretty crazy
    duf # like du, but for free space

    # `, <cmd>` runs any program from nixpkgs without installing it, resolving
    # the command through the nix-index database configured below.
    comma
  ];

  # If command is not present, it tells us where it can be found
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  # `bat`: cat clone with syntax highlighting + git integration.
  # theme = "base16" renders through the terminal's live ANSI palette, so bat
  # tracks the active Ember / base16-shell colors automatically.
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "numbers,changes,header";
    };
  };

  programs.zsh = {
    enable = true;
    sessionVariables = {
      # Default from https://github.com/zsh-users/zsh-autosuggestions
      EDITOR = "nvim";
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE = "fg=8";
      ZSH_AUTOSUGGEST_STRATEGY = "(history completion)";
      ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = 20; # Only suggest up to 20 characters
    };
    initContent = lib.mkMerge [
      (keyBindings
        + fzf-tab-conf
        + ''
            # ctrl-w, alt-b (etc.) stop at chars like `/:` instead of just space
            autoload -U select-word-style
            select-word-style bash

            # Base16 Shell colors!
            BASE16_SHELL="$HOME/.config/base16-shell/"
            [ -n "$PS1" ] && \
                [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
                    source "$BASE16_SHELL/profile_helper.sh"

            export FZF_DEFAULT_OPTS="
            --bind='ctrl-e:execute($EDITOR {} > /dev/tty )+abort'
            "

            # Resolve a command through the nix store (the old alias version
            # had an unclosed backtick and just hung the prompt).
            whichnix () {
              readlink -f "$(which "$1")"
            }

            # System generation switcher with television preview (same as
            # nushell's ng, see terminal/nushell.nix for the why of each part).
            ng () {
              local gen num link
              gen=$(
                for link in /nix/var/nix/profiles/system-*-link; do
                  num="''${link##*system-}"
                  num="''${num%-link}"
                  # stat the link itself: its target's mtime is nix-normalized to 1970
                  printf '%s %s\n' "$num" "$(stat -c '%.16y' "$link")"
                done | sort -rn \
                  | tv --preview-command "nvd diff '/nix/var/nix/profiles/system-{split: :0}-link' /nix/var/nix/profiles/system"
              )
              if [[ -n "$gen" ]]; then
                nh os switch "/nix/var/nix/profiles/system-''${gen%% *}-link"
              fi
            }

          	# ${pkgs.pywal}/bin/wal -i $(cat ~/.cache/swww/eDP-1) -q -n
        '')
    ];
    autocd = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs"; # this is the default, don't get scared
    autosuggestion.enable = true;
    enableCompletion = true;
    history = {
      ignoreDups = true;
      extended = true;
      save = 1000000;
      size = 1000000;
      share = true;
    };
    # TODO: integrate better (this silently ignores if config.themes.extraShellAliases is not set)
    shellAliases = {
      fm = fileManager;
      # git
      wow = "git status --untracked-files=no";
      # eza
      ls = "eza -lahF --git";
      # TODO: Check if this prints the last branch from which the current branch forked
      git-parent = "git log --pretty=format:'%D' HEAD^ | grep 'origin/' | head -n1 | sed 's@origin/@@' | sed 's@,.*@@'";

    };
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        file = "fzf-tab.plugin.zsh";
      }
      {
        # Don't know what this is
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions;
      }
      {
        name = "zsh-autopair";
        file = "share/zsh/zsh-autopair/autopair.zsh";
        src = pkgs.zsh-autopair;
      }
      {
        name = "zsh-autosuggestions";
        src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
        src = pkgs.zsh-syntax-highlighting;
      }
    ];
  };
}
