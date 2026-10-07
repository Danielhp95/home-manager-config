# Shell history: atuin, its daemon, and the PTY proxy zsh starts under.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # atuin's PTY proxy keeps a shadow vt100, so the Ctrl-R popup draws over the
  # scrollback and restores it. Not atuin's `[pty_proxy] enabled`: that execs
  # from home-manager's late `atuin init` line, so most of .zshrc would run
  # twice. The exec lines are pinned to the store path; PATH isn't set yet.
  atuinPtyProxyZsh = pkgs.runCommand "atuin-pty-proxy-init.zsh" { } ''
    ${lib.getExe config.programs.atuin.package} pty-proxy init zsh > $out
    substituteInPlace $out \
      --replace-fail 'exec atuin pty-proxy' 'exec ${lib.getExe config.programs.atuin.package} pty-proxy'
  '';
in
{
  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    enableZshIntegration = true;
    # Socket-activated user service on $XDG_RUNTIME_DIR/atuin.sock. Not
    # settings.daemon.autostart: its $TMPDIR socket let a sandboxed shell with
    # a private /tmp start a second daemon, which stalled every command.
    daemon.enable = true;
    settings = {
      enter_accept = true; # Enter to execute, tab to select
      show_help = false;
      show_tabs = false;
      invert = true;
      ai = {
        enabled = true;
      };
      # Ctrl-R opens filtered to the current git repo (Ctrl-R cycles out).
      workspaces = true;
      # No theme on purpose: atuin's built-in colours beat an Ember one.
    };
  };
  # The proxy runs only for shells sitting directly in a terminal window;
  # tmux panes get plain zsh and drop the proxy variables the server
  # inherited. mkOrder 100: the exec re-reads .zshrc, so anything sourced
  # before it runs twice.
  # Tty guard: a shell on a new tty (nvim's :terminal) must drop a socket
  # owned by another terminal, or Ctrl-R replays that terminal's screen. The
  # TTY variable is cleared before the source so a fresh proxy keeps its own.
  # `source`, not builtins.readFile of a derivation (import-from-derivation).
  programs.zsh.initContent = lib.mkOrder 100 ''
    if [[ -n ''${TMUX:-} ]]; then
      unset ATUIN_PTY_PROXY_ACTIVE ATUIN_PTY_PROXY_TMUX \
        ATUIN_PTY_PROXY_SOCKET ATUIN_PTY_PROXY_TTY
    else
      _atuin_pty_proxy_owner_tty=''${ATUIN_PTY_PROXY_TTY:-}
      unset ATUIN_PTY_PROXY_TTY
      if [[ -n ''${ATUIN_PTY_PROXY_SOCKET:-} && -n $_atuin_pty_proxy_owner_tty \
            && $_atuin_pty_proxy_owner_tty != ''${TTY:-$(tty)} ]]; then
        unset ATUIN_PTY_PROXY_SOCKET
      fi
      unset _atuin_pty_proxy_owner_tty
      source ${atuinPtyProxyZsh}
      export ATUIN_PTY_PROXY_TTY=''${TTY:-$(tty)}
    fi
  '';
}
