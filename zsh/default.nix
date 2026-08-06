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
  p = (import ../palette.nix).hash;
  # Ember styling for zsh-syntax-highlighting. The plugin's defaults use
  # named ANSI colors; overriding with palette.nix hex keeps the prompt in
  # the same voice as starship: commands are the coral hero, strings olive
  # (the editor convention — gold is rationed for attention states like
  # sudo), paths/options steel, structure mauve, comments legible fgDim.
  syntax-highlight-conf = ''
    typeset -A ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

    # The command word — coral, where the eye lands
    ZSH_HIGHLIGHT_STYLES[command]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[function]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[global-alias]='fg=${p.accent}'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=${p.accentBright},italic'
    ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=${p.accentDim},italic'
    # error is near-equiluminant with accent, so it never rides on hue alone
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=${p.error},bold'

    # Strings — olive, the editor convention
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=${p.olive}'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=${p.olive}'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=${p.olive}'
    ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=${p.olive}'

    # Interpolation inside strings — steel, so it reads through the olive
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=${p.steel}'

    # Injected/dynamic values — sage
    ZSH_HIGHLIGHT_STYLES[assign]='fg=${p.sage}'
    ZSH_HIGHLIGHT_STYLES[named-fd]='fg=${p.sage}'
    ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=${p.sage}'

    # Paths and options — steel
    ZSH_HIGHLIGHT_STYLES[path]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=${p.muted}'
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=${p.muted}'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=${p.steel}'

    # Shell structure — mauve
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[redirection]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[process-substitution]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=${p.fgDim}'
    # comments are read, not decoration: muted is 3.2:1 on bg, below AA
    ZSH_HIGHLIGHT_STYLES[comment]='fg=${p.fgDim},italic'
    ZSH_HIGHLIGHT_STYLES[arg0]='fg=${p.fg}'
    ZSH_HIGHLIGHT_STYLES[default]='fg=${p.fg}'

    # Nested brackets cycle through the secondary hues
    ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=${p.steel}'
    ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=${p.gold}'
    ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=${p.sage}'
    ZSH_HIGHLIGHT_STYLES[bracket-level-4]='fg=${p.mauve}'
    ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=${p.error}'
    ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]='fg=${p.accentBright},bold'
  '';
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
        + syntax-highlight-conf
        + ''
            # ctrl-w, alt-b (etc.) stop at chars like `/:` instead of just space
            autoload -U select-word-style
            select-word-style bash

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
    localVariables = {
      # Skip zsh-autosuggestions' per-prompt rebind of every zle widget (it
      # re-wraps the whole widget table each precmd to catch late-defined
      # widgets — all of ours exist by first prompt). Revert if suggestions
      # ever stop updating for some widget.
      ZSH_AUTOSUGGEST_MANUAL_REBIND = 1;
    };
    # `compinit -C` trusts the cached .zcompdump and skips the compaudit
    # security scan; do the full (slow: ~320ms vs ~5ms) init only when the
    # dump is >24h old, so newly installed completions still get picked up
    # within a day. Two gotchas this encodes: the (#q) glob qualifier
    # silently never matches inside [[ ]] without EXTENDED_GLOB, and a full
    # compinit leaves the dump's mtime untouched when nothing changed — so
    # touch it, or once stale it stays on the slow path forever.
    completionInit = ''
      autoload -U compinit
      () {
        setopt local_options extended_glob
        local dump=''${ZDOTDIR:-$HOME}/.zcompdump
        if [[ ! -e $dump || -n $dump(#qN.mh+24) ]]; then
          compinit -d $dump
          touch $dump
        else
          compinit -C -d $dump
        fi
      }
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
