{ lib, config, pkgs, ... }:
let
  keyBindings = builtins.readFile ./key-bindings.zsh;
  fzf-tab-conf = ''
    zstyle ":completion:*:git-checkout:*" sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':completion:*' list-colors ${"\${(s.:.)LS_COLORS}"}
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
  '';
in
{
  home.packages = with pkgs; [
    nix-zsh-completions

    # rust alternatives
    fd # find alternative
    bat # cat alternative
    du-dust # du alternative. Pretty crazy
    duf  # like du, but for free space
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
        # Hack to get colored man pages, for some reason MANPAGER would not work properly if set on envExtra (see above)
        man = "MANPAGER=\"less -R --use-color -Dd+r -Du+b\" man";

        # rust alternatives
        du = "dust";
        # TODO: Check if this prints the last branch from which the current branch forked
        git-parent = "git log --pretty=format:'%D' HEAD^ | grep 'origin/' | head -n1 | sed 's@origin/@@' | sed 's@,.*@@'";
      };
      plugins = [
        { name = "nix-zsh-completions"; src = pkgs.nix-zsh-completions; }
        { name = "zsh-autopair"; src = pkgs.nix-zsh-completions; }
        {
          name = "fzf-tab";
          src = pkgs.fetchFromGitHub {
            owner = "Aloxaf";
            repo = "fzf-tab";
            rev = "190500bf1de6a89416e2a74470d3b5cceab102ba";
            sha256 = "sha256-C6cE96YXyYP1RxpCLVtG1hcYLluplPLiIdkdo4HXN7Y=";
          };
          file = "fzf-tab.plugin.zsh";
        }
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "caa749d030d22168445c4cb97befd406d2828db0";
            sha256 = "sha256-YV9lpJ0X2vN9uIdroDWEize+cp9HoKegS3sZiSpNk50=";
          };
        }
      ];
    };
  };
}
