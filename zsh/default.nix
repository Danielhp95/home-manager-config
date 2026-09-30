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
  p = (import ../palette.nix).hash;
  # Flags a booted kernel whose module tree no longer matches the current
  # system profile. This is the running-system half of the ESP sync check
  # (esp-check, non_home_manager_config/configuration.nix): it's what would
  # have caught the running kernel's modules getting GC'd out from under it
  # before the machine actually needed to reboot into them. See
  # kernel-bootloader-drift memory.
  kernelDriftCheck = ''
    __profile_modules=(/nix/var/nix/profiles/system/kernel-modules/lib/modules/*(N))
    if [[ -n $__profile_modules[1] ]]; then
      __profile_kernel=''${__profile_modules[1]:t}
      if [[ $__profile_kernel != $(uname -r) ]]; then
        print -P "%F{#${p.error}}reboot: kernel/profile mismatch%f (running $(uname -r), profile has $__profile_kernel)"
      fi
    fi
    unset __profile_modules __profile_kernel
  '';
  # Ember styling for zsh-syntax-highlighting. The plugin's defaults use
  # named ANSI colors; overriding with palette.nix hex keeps the prompt in
  # the same voice as starship: commands are the coral hero, strings olive
  # (the editor convention), paths gold (by request — the thing you typed
  # `cd` for deserves the emphasis color), options/interpolation steel
  # (magma), structure mauve, comments legible fgDim.
  syntaxHighlightStyles = {
    # The command word — coral, where the eye lands
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

    # Strings — olive, the editor convention
    single-quoted-argument = "fg=${p.olive}";
    double-quoted-argument = "fg=${p.olive}";
    dollar-quoted-argument = "fg=${p.olive}";
    rc-quote = "fg=${p.olive}";

    # Interpolation inside strings — steel, so it reads through the olive
    dollar-double-quoted-argument = "fg=${p.steel}";
    back-quoted-argument = "fg=${p.steel}";
    back-double-quoted-argument = "fg=${p.steel}";
    back-dollar-quoted-argument = "fg=${p.steel}";

    # Injected/dynamic values — sage
    assign = "fg=${p.sage}";
    named-fd = "fg=${p.sage}";
    numeric-fd = "fg=${p.sage}";

    # Paths — gold (the cd argument is the point of the command); options
    # stay on steel with the rest of the quiet metadata
    path = "fg=${p.gold}";
    path_prefix = "fg=${p.gold}";
    path_pathseparator = "fg=${p.muted}";
    path_prefix_pathseparator = "fg=${p.muted}";
    single-hyphen-option = "fg=${p.steel}";
    double-hyphen-option = "fg=${p.steel}";

    # Shell structure — mauve
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

    # Nested brackets cycle through the secondary hues
    bracket-level-1 = "fg=${p.steel}";
    bracket-level-2 = "fg=${p.gold}";
    bracket-level-3 = "fg=${p.sage}";
    bracket-level-4 = "fg=${p.mauve}";
    bracket-error = "fg=${p.error}";
    cursor-matchingbracket = "fg=${p.accentBright},bold";
  };
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages = with pkgs; [
    fd # find alternative
    dust # du alternative. Pretty crazy
    duf # like du, but for free space
    # Completions for nix-env, nix-build, nix-shell and friends, picked up
    # from the profile's share/zsh/site-functions. NixOS would install it
    # too, but configuration.nix turns its programs.zsh.enableCompletion off.
    nix-zsh-completions
  ];

  # If command is not present, it tells us where it can be found. The
  # database itself comes from the nix-index-database flake input (wired in
  # as a shared HM module in flake.nix), which drops a prebuilt weekly index
  # into ~/.cache/nix-index — `nix-index` was never run by hand here, so the
  # cache sat empty and both the hook and `comma` were inert.
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  # `, <cmd>` runs any program from nixpkgs without installing it. The module
  # ships comma wrapped to that same database (pkgs.comma on its own would
  # collide with it in home.packages).
  programs.nix-index-database.comma.enable = true;

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
      EDITOR = "nvim";
    };
    initContent = lib.mkMerge [
      # Order 850: before home-manager sources the plugins (order 900), so
      # zsh-autopair picks up these space/backspace bindings as its fallbacks
      # instead of having them overwritten afterwards, and
      # zsh-syntax-highlighting (order 1200, see syntaxHighlighting below)
      # hooks into the zle-line-init/finish widgets defined here rather than
      # being unhooked by them.
      (lib.mkOrder 850 keyBindings)
      (
        fzf-tab-conf
        + kernelDriftCheck
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
        ''
      )
      # starship's zsh init sets *both* PROMPT and RPROMPT to a
      # `$(starship prompt …)` command substitution, and it does so
      # unconditionally — emptying `right_format` in starship's settings
      # still forks a second starship on every prompt, it just forks one
      # that prints nothing. Clearing RPROMPT is what actually removes the
      # fork (measured: 3.3ms of the ~29ms Enter-to-new-prompt round trip).
      # Everything renders on the left instead; see the
      # `format` comment in ../starship/default.nix.
      #
      # mkAfter (order 1500) is load-bearing: the home-manager starship
      # module contributes its `eval` with no explicit order, i.e. at the
      # default 1000, so an unordered block here would tie with it and the
      # winner would be merge order — a coin flip that starship wins by
      # re-setting RPROMPT afterwards. The assignment is one-shot (starship
      # sets RPROMPT at init time, not from its precmd hook), so clearing
      # it once sticks.
      (lib.mkAfter ''
        RPROMPT=""
      '')
    ];
    autocd = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs"; # this is the default, don't get scared
    autosuggestion = {
      enable = true;
      # atuin's zsh init prepends its own "atuin" strategy to this list
      strategy = [
        "history"
        "completion"
      ];
    };
    enableCompletion = true;
    # home-manager sources it at order 1200, after every widget this file and
    # the other integrations define, which is where the plugin has to load
    syntaxHighlighting = {
      enable = true;
      # "main" is always prepended by home-manager; listing it again would
      # run it twice
      highlighters = [ "brackets" ];
      styles = syntaxHighlightStyles;
    };
    localVariables = {
      # Skip zsh-autosuggestions' per-prompt rebind of every zle widget (it
      # re-wraps the whole widget table each precmd to catch late-defined
      # widgets — all of ours exist by first prompt). Revert if suggestions
      # ever stop updating for some widget.
      ZSH_AUTOSUGGEST_MANUAL_REBIND = 1;
      # Stop fetching suggestions once the line typed so far is longer than
      # 20 characters
      ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = 20;
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
    shellAliases = {
      fm = fileManager;
      # git
      wow = "git status --untracked-files=no";
      # eza
      ls = "eza -lahF --git";
      # Nearest ancestor of HEAD that carries an origin/* ref. That is the
      # branch this one forked from only while this branch is unpushed; once
      # pushed, its own upstream wins.
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
