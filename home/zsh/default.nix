{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
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
  p = (import ../../palette).hash;
  # Warns when the booted kernel no longer matches the system profile's (its
  # modules can be GC'd); the running-system half of
  # nixos/esp-check.nix.
  kernelDriftCheck = ''
    __profile_modules=(/nix/var/nix/profiles/system/kernel-modules/lib/modules/*(N))
    if [[ -n $__profile_modules[1] ]]; then
      __profile_kernel=''${__profile_modules[1]:t}
      if [[ $__profile_kernel != $(uname -r) ]]; then
        print -P "%F{${p.error}}reboot: kernel/profile mismatch%f (running $(uname -r), profile has $__profile_kernel)"
      fi
    fi
    unset __profile_modules __profile_kernel
  '';
  # The palette for zsh-syntax-highlighting, in starship's voice: commands the
  # accent, options its dim step, paths lavender, strings olive, interpolation
  # steel, structure mauve.
  syntaxHighlightStyles = {
    command = "fg=${p.accent}";
    builtin = "fg=${p.accent}";
    function = "fg=${p.accent}";
    alias = "fg=${p.accent}";
    suffix-alias = "fg=${p.accent}";
    global-alias = "fg=${p.accent}";
    precommand = "fg=${p.accentBright},italic";
    autodirectory = "fg=${p.accentDim},italic";
    # error is near-equiluminant with accent, so it never rides on hue alone
    unknown-token = "fg=${p.error},bold";

    single-quoted-argument = "fg=${p.olive}";
    double-quoted-argument = "fg=${p.olive}";
    dollar-quoted-argument = "fg=${p.olive}";
    rc-quote = "fg=${p.olive}";

    dollar-double-quoted-argument = "fg=${p.steel}";
    back-quoted-argument = "fg=${p.steel}";
    back-double-quoted-argument = "fg=${p.steel}";
    back-dollar-quoted-argument = "fg=${p.steel}";

    assign = "fg=${p.sage}";
    named-fd = "fg=${p.sage}";
    numeric-fd = "fg=${p.sage}";

    # lavender ink; the underline keeps an existing path distinct from plain words
    path = "fg=${p.fgSoft},underline";
    path_prefix = "fg=${p.fgDim},underline";
    path_pathseparator = "fg=${p.muted}";
    path_prefix_pathseparator = "fg=${p.muted}";
    single-hyphen-option = "fg=${p.accentDim}";
    double-hyphen-option = "fg=${p.accentDim}";

    reserved-word = "fg=${p.mauve}";
    globbing = "fg=${p.mauve}";
    history-expansion = "fg=${p.mauve}";
    redirection = "fg=${p.mauve}";
    process-substitution = "fg=${p.mauve}";
    process-substitution-delimiter = "fg=${p.mauve}";
    command-substitution-delimiter = "fg=${p.mauve}";
    commandseparator = "fg=${p.fgDim}";
    # comments are read, not decoration: muted is 3.2:1 on bg, below AA
    comment = "fg=${p.fgDim},italic";
    arg0 = "fg=${p.fg}";
    default = "fg=${p.fg}";

    bracket-level-1 = "fg=${p.accentBright}";
    bracket-level-2 = "fg=${p.mauve}";
    bracket-level-3 = "fg=${p.accentDim}";
    bracket-level-4 = "fg=${p.sage}";
    bracket-error = "fg=${p.error}";
    cursor-matchingbracket = "fg=${p.accentBright},bold";
  };
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages = with pkgs; [
    fd # find alternative
    dust # du alternative
    duf # like du, but for free space
    # nix-env/nix-build/nix-shell completions; NixOS's copy is off because
    # nixos/default.nix disables its programs.zsh.enableCompletion
    nix-zsh-completions
  ];

  # command-not-found hints, from the prebuilt nix-index-database index
  # (imported above) rather than a hand-run `nix-index`
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  # `, <cmd>` runs any nixpkgs program without installing it (pkgs.comma on
  # its own would collide with this wrapped one)
  programs.nix-index-database.comma.enable = true;

  # base16 renders through the terminal's ANSI palette, so bat follows Ember
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "numbers,changes,header";
    };
  };

  # Man pages through bat's Manpage syntax, in the same ANSI theme. bat cannot
  # read groff's colour escapes: -c makes groff overstrike instead, and col
  # strips that.
  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };

  # The syntax-highlighting styles again, as a file a running shell can
  # re-read (see the precmd hook in initContent), and with them the
  # file-listing colours (../terminal/ls-colors.nix) and the completion
  # menu's copy of those.
  xdg.configFile."zsh/palette.zsh".text =
    lib.concatStrings (
      lib.mapAttrsToList (
        name: style: "ZSH_HIGHLIGHT_STYLES[${name}]=${lib.escapeShellArg style}\n"
      ) config.programs.zsh.syntaxHighlighting.styles
    )
    + ''
      export LS_COLORS=${lib.escapeShellArg config.home.sessionVariables.LS_COLORS}
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
    '';

  programs.zsh = {
    enable = true;
    sessionVariables = {
      EDITOR = "nvim";
    };
    # Session variables are read once per login, and a tmux server keeps the
    # environment it started with. Restated per shell, these reach a new pane
    # without either being restarted.
    envExtra =
      lib.concatMapStrings
        (name: "export ${name}=${lib.escapeShellArg config.home.sessionVariables.${name}}\n")
        [
          "FZF_DEFAULT_OPTS"
          "FZF_DEFAULT_OPTS_FILE"
          "GLAMOUR_STYLE"
          "LS_COLORS"
          "MANPAGER"
          "MANROFFOPT"
        ];
    initContent = lib.mkMerge [
      # Order 850, before HM sources the plugins (900): autopair wraps these
      # space/backspace bindings instead of losing its own to them, and
      # zsh-syntax-highlighting (1200) keeps its zle-line-finish hook.
      (lib.mkOrder 850 keyBindings)
      (
        fzf-tab-conf
        + kernelDriftCheck
        + ''
          # ctrl-w, alt-b (etc.) stop at chars like `/:` instead of just space
          autoload -U select-word-style
          select-word-style bash

          # zoxide's picker (zi, `z foo<Space><Tab>`) replaces FZF_DEFAULT_OPTS
          # with this, so re-seed the ambient opts. Lines are "score path"
          # (hence {2..}); a bare --icons would eat the path as its WHEN value.
          export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS --height 40% --tmux center,70%,60% --preview-window=down --preview 'eza -1 --color=always --icons=always {2..}'"

          # Run a command on an interactively picked frecent dir: `zz nvim`
          zz () {
            local dir
            dir="$(zoxide query -i)" || return
            "$@" "$dir"
          }

          # Resolve a command to its nix store path
          whichnix () {
            readlink -f "$(which "$1")"
          }

          # Generation switcher (television channel in terminal/television.nix)
          alias ng="tv nix-generations"
        ''
      )
      # starship's init points RPROMPT at a second `starship prompt` fork even
      # with an empty right_format; clearing it saves that fork per prompt.
      # mkAfter matters: starship's init sits at the default order, and a tie
      # could let it set RPROMPT again after this.
      (lib.mkAfter ''
        RPROMPT=""

        # A palette switch reaches shells that are already running: when the
        # styles file changes (its store path does), the next prompt re-reads it.
        __palette_styles=$ZDOTDIR/palette.zsh
        __palette_seen=''${__palette_styles:A}
        __palette_refresh () {
          [[ ''${__palette_styles:A} == $__palette_seen ]] && return
          __palette_seen=''${__palette_styles:A}
          source $__palette_styles
        }
        precmd_functions+=(__palette_refresh)
      '')
    ];
    autocd = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs"; # load-bearing: with EDITOR=nvim zsh would pick vi insert mode
    autosuggestion = {
      enable = true;
      # atuin's zsh init prepends its own "atuin" strategy to this list
      strategy = [
        "history"
        "completion"
      ];
    };
    enableCompletion = true;
    # HM sources it at order 1200, after every widget is defined, as it needs
    syntaxHighlighting = {
      enable = true;
      # HM always prepends "main"; listing it again would run it twice
      highlighters = [ "brackets" ];
      styles = syntaxHighlightStyles;
    };
    localVariables = {
      # Skip autosuggestions' per-prompt re-wrap of every widget (ours all
      # exist by the first prompt); revert if suggestions stop updating
      ZSH_AUTOSUGGEST_MANUAL_REBIND = 1;
      # No suggestions once the typed line is longer than this
      ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = 20;
    };
    # Full compinit (~320ms) only when the dump is over 24h old, else -C
    # (~5ms). (#q) needs EXTENDED_GLOB inside [[ ]], and the touch matters: a
    # no-change compinit leaves the mtime alone, keeping later shells slow.
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
    shellAliases = {
      fm = fileManager;
      wow = "git status --untracked-files=no";
      ls = "eza -lahF --git";
      # Nearest ancestor carrying an origin/* ref: the fork point only while
      # this branch is unpushed
      git-parent = "git log --pretty=format:'%D' HEAD^ | grep 'origin/' | head -n1 | sed 's@origin/@@' | sed 's@,.*@@'";

    };
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        file = "fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-autopair";
        file = "share/zsh/zsh-autopair/autopair.zsh";
        src = pkgs.zsh-autopair;
      }
    ];
  };
}
