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
  # tracks the active Ember colors automatically.
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

            # Append (the fzf module already fills FZF_DEFAULT_OPTS with the
            # Ember colors via sessionVariables; plain export clobbered them)
            export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
            --bind='ctrl-e:execute($EDITOR {} > /dev/tty )+abort'
            "

            # zi / `z foo<Space><Tab>` picker: zoxide replaces
            # FZF_DEFAULT_OPTS with this when it spawns fzf, so re-seed it
            # with the ambient opts. Lines are "score path" -> {2..} is path.
            # (--icons needs =always: with a bare --icons eza parses the
            # following path as the flag's optional WHEN value)
            # --tmux renders the picker in a tmux popup (styled by tmux.conf's
            # popup-border settings); --height is the fallback outside tmux
            export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS --height 40% --tmux center,70%,60% --preview-window=down --preview 'eza -1 --color=always --icons=always {2..}'"

            # Run any command with an interactively-picked frecent dir as the
            # last argument: `zz nvim`, `zz eza -la`, ...
            zz () {
              local dir
              dir="$(zoxide query -i)" || return
              "$@" "$dir"
            }

            # Resolve a command through the nix store (the old alias version
            # had an unclosed backtick and just hung the prompt).
            whichnix () {
              readlink -f "$(which "$1")"
            }

            # System generation switcher (cable channel in
            # terminal/television.nix; enter runs `nh os switch`)
            alias ng="tv nix-generations"
        '')
    ];
    autocd = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs"; # this is the default, don't get scared
    autosuggestion.enable = true;
    enableCompletion = true;
    # `compinit -C` trusts the cached .zcompdump and skips the compaudit
    # security scan; do the full (slow) init only when the dump is >24h old,
    # so newly installed completions still get picked up within a day.
    completionInit = ''
      autoload -U compinit
      if [[ -n ''${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
        compinit
      else
        compinit -C
      fi
    '';
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
