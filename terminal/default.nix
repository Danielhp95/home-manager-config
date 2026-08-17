{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  p = (import ../palette.nix).hash;

  # Atuin's PTY proxy — the feature that shipped as `atuin hex` in v18.13 and
  # was renamed to `atuin pty-proxy` before this version. It is a minimal
  # tmux-alike: it proxies bytes between the terminal and the shell while
  # keeping a shadow vt100, which is what lets the Ctrl-R popup draw *over*
  # your previous output and then restore it. Without it atuin has to pick
  # between clearing the scrollback (inline) or taking the whole screen (alt
  # screen); inline_height = 40 above is the setting that trade-off comes from.
  #
  # There is no config.toml switch for it — activation is purely this shell
  # snippet, which `exec`s the proxy and lets it respawn zsh underneath.
  #
  # Generated at build time rather than `eval "$(atuin pty-proxy init zsh)"`,
  # for the same reason the IRIS hook in iris.nix is inlined: that eval is a
  # subprocess on every single interactive zsh start. The cost of pinning it
  # is that upstream changes to the snippet only land on rebuild — which is
  # what we want, since a silent upstream change to an `exec` line in .zshrc
  # is exactly the kind of thing that should be reviewed, not absorbed.
  #
  # The sed pins `atuin` to the store path. The snippet runs at the very top
  # of .zshrc, before anything here has touched PATH, so a bare `atuin` would
  # depend on the login environment having already exported it.
  atuinPtyProxyZsh = pkgs.runCommand "atuin-pty-proxy-init.zsh" { } ''
    ${config.programs.atuin.package}/bin/atuin pty-proxy init zsh > $out
    sed -i 's|exec atuin pty-proxy|exec ${config.programs.atuin.package}/bin/atuin pty-proxy|g' $out
  '';
in
{
  # Zoxide database hygiene. Literal paths (not $HOME) because the nushell
  # module loads sessionVariables without shell expansion.
  home.sessionVariables = {
    # Skip ~ itself (jumping "home" is trivial), the store, and .git internals
    _ZO_EXCLUDE_DIRS = "${config.home.homeDirectory}:/nix/store/*:*/.git/*";
    # Dedupe symlinked paths before scoring — most things are symlinks on NixOS
    _ZO_RESOLVE_SYMLINKS = "1";
  };

  home.packages = with pkgs; [
    fira-code
    powerline-fonts
    nix-search-tv
    rsync
  ];
  # Do NOT force TERM globally: the terminal emulator sets its own TERM, and inside
  # tmux it must stay tmux-256color. Forcing "kitty" makes nvim emit kitty-specific
  # sequences through tmux, which corrupts rendering (e.g. scrolling one split
  # visually scrolls all windows).
  programs = {
    btop = {
      package = pkgs.btop-cuda;
      enable = true;
      settings = {
        shown_boxes = "cpu proc";
        vim_keys = true;
        rounded_corners = true;
      };
    };
    # Really nice shell history
    atuin = {
      enable = true;
      # package = inputs.stable.legacyPackages.x86_64-linux.atuin;
      flags = [ "--disable-up-arrow" ];
      enableZshIntegration = true;
      settings = {
        enter_accept = true; # Enter to execute, tab to select
        show_help = false;
        show_tabs = false;
        invert = true;
        # search_mode = "daemon-fuzzy";
        daemon = {
          autostart = true;
          enabled = true;
        };
        ai = {
          enabled = true;
        };
      };
    };
    # Activate the PTY proxy (see atuinPtyProxyZsh above for what it buys).
    #
    # mkOrder 100 puts this ahead of every other initContent block, including
    # the mkBefore ones in iris.nix and zsh/default.nix. Ordering is about cost,
    # not correctness: the snippet `exec`s a proxy that respawns zsh, so that
    # second zsh re-reads .zshrc from the top. Everything sourced before the
    # exec is therefore paid for twice and thrown away — compinit, the plugin
    # sourcing, starship. First in the file means the wasted half is nothing.
    #
    # The re-exec is self-limiting: the snippet exports ATUIN_PTY_PROXY_ACTIVE
    # and skips when it is already set. Two consequences worth knowing:
    #
    #   - IRIS is unaffected. `i` execs a wrapper that spawns its own child
    #     zsh, and that child inherits the variable, so it does not stack a
    #     second proxy inside the first. The chain is proxy -> zsh -> iris ->
    #     zsh, with one shadow vt100 at the outside.
    #   - tmux is deliberately *not* exempt. The snippet also re-execs when
    #     $TMUX changes, so panes get their own proxy rather than inheriting
    #     the outer one — that is what keeps the popup's redraw aligned with
    #     the pane's scrollback rather than the outer terminal's.
    #
    # `source` rather than inlining the text with builtins.readFile: readFile
    # on a derivation is import-from-derivation, which drags a build into
    # every evaluation of this flake. Sourcing a store path costs one cached
    # file read per shell and keeps eval pure.
    zsh.initContent = lib.mkOrder 100 "source ${atuinPtyProxyZsh}";
    # `ls` replacement
    eza.enable = true;
    # Smart cd (also feeds yazi's builtin z/Z jumps)
    zoxide.enable = true;
    # The one, the fuzzy searcher
    fzf = {
      enable = true;
      # fzf 0.74's bundled nushell integration (shell/completion.nu, emitted by
      # `fzf --nushell` and sourced into config.nu by home-manager) still uses
      # `str downcase`, deprecated in nushell 0.114 — it warns on every nu
      # startup. Patch it to `str lowercase`; drop once upstream fzf is fixed.
      package = pkgs.fzf.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace shell/completion.nu \
            --replace-quiet 'str downcase' 'str lowercase'
        '';
      });
      # Atuin owns Ctrl-R (sourced after fzf); disable fzf's history widget to
      # silence the HM Ctrl-R conflict warning without changing behavior.
      historyWidget.command = "";
      historyWidget.nushell.command = "";
      # Open the selection in an editor. This has to be set declaratively here
      # rather than appended from shell init: FZF_DEFAULT_OPTS is exported, so
      # an `export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind=..."` in zshrc
      # re-appends at every nesting level and the binding accumulates (a shell
      # three levels deep — terminal, tmux, subshell — carried three copies).
      # home-manager writes this into the session vars for zsh and nushell
      # alike, as a plain assignment, so it lands exactly once.
      #
      # Literal `nvim`, not `$EDITOR`: nushell loads these without shell
      # expansion. Both shells set EDITOR = "nvim" anyway.
      defaultOptions = [ "--bind='ctrl-e:execute(nvim {} > /dev/tty)+abort'" ];
      # Ember colors from palette.nix — coral for match highlights and the
      # pointer, steel for neutral chrome (gold is rationed for
      # needs-attention states, and at 8.4:1 it would outshine the coral)
      colors = {
        bg = p.bg;
        "bg+" = p.surface;
        fg = p.fg;
        "fg+" = p.fg;
        hl = p.accent;
        "hl+" = p.accentBright;
        info = p.steel;
        marker = p.accent;
        prompt = p.accent;
        spinner = p.sage;
        pointer = p.accent;
        header = p.olive;
        border = p.border;
        label = p.steel;
        query = p.fg;
      };
    };
  };

}
