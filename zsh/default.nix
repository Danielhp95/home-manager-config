{ lib, config, pkgs, ... }:
let
  keyBindings = builtins.readFile ./key-bindings.zsh;
  fzf-tab-conf = ''
    zstyle ":completion:*:git-checkout:*" sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':completion:*' list-colors ${"\${(s.:.)LS_COLORS}"}

    # Completions for specific programs
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
  '';
in {
  home.packages = with pkgs; [
    nix-zsh-completions

    # rust alternatives
    fd # find alternative
    bat # cat alternative
    du-dust # du alternative. Pretty crazy
    duf # like du, but for free space
    most
  ];

  # If command is not present, it tells us where it can be found
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  programs = {
    eza.enable = true;
    fzf.enable = true;
    zsh = {
      enable = true;
      sessionVariables = {
        PAGER = "most";
        # Default from https://github.com/zsh-users/zsh-autosuggestions
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE = "fg=8";
        ZSH_AUTOSUGGEST_STRATEGY="(history completion)";
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20;  # Only suggest up to 20 characters
      };
      initExtra = keyBindings + fzf-tab-conf + ''
        # ctrl-w, alt-b (etc.) stop at chars like `/:` instead of just space
        autoload -U select-word-style
        select-word-style bash

        bindkey ' ' magic-space          # [Space] - don't do history expansion

        # Edit the current command line in $EDITOR
        autoload -U edit-command-line
        zle -N edit-command-line
        bindkey '\C-e\C-e' edit-command-line

        # Base16 Shell colors!
        BASE16_SHELL="$HOME/.config/base16-shell/"
        [ -n "$PS1" ] && \
            [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
                source "$BASE16_SHELL/profile_helper.sh"

        export FZF_DEFAULT_OPTS="
        --bind='ctrl-e:execute($EDITOR {} > /dev/tty )+abort'
        "

        ${pkgs.pywal}/bin/wal -i $(cat ~/.cache/swww/eDP-1) -q -n
      '';
      autocd = true;
      dotDir = ".config/zsh";
      defaultKeymap = "emacs"; # this is the default, don't get scared
      autosuggestion.enable = true;
      enableCompletion = true;
      # envExtra = ''
      #   EDITOR=nvim
      #   TERM=xterm-256color
      # '';
      history = {
        ignoreDups = true;
        extended = true;
        save = 1000000;
        size = 1000000;
        share = true;
      };
      # TODO: integrate better (this silently ignores if config.themes.extraShellAliases is not set)
      shellAliases = {
        # nix
        whichnix = "readlink -f `which ";

        # git
        wow = "git status";

        # eza
        ls = "eza -lahF --git";

        # rust alternatives
        du = "dust";
        # TODO: Check if this prints the last branch from which the current branch forked
        git-parent =
          "git log --pretty=format:'%D' HEAD^ | grep 'origin/' | head -n1 | sed 's@origin/@@' | sed 's@,.*@@'";
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
        # Does not work
        {
          name = "zsh-autopair";
          file = "share/zsh/zsh-autopair/autopair.zsh";
          src = pkgs.zsh-autopair;
        }
        {
          name = "zsh-autosuggestions";
          src =
            "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "zsh-syntax-highlighting";
          file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
          src = pkgs.zsh-syntax-highlighting;
        }
      ];
    };
  };
}
