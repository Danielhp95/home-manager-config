{ pkgs, lib, config, ... }:

let
  p = (import ../palette.nix).hash;
  # The @color_* variables tmux.conf renders with, generated from palette.nix
  # so tmux, starship and the rest of the system share one source of truth.
  emberColors = ''
    # ── Ember palette — GENERATED from palette.nix by default.nix ──
    # Surfaces
    set -g @color_bg0 "${p.bg}"
    set -g @color_bg1 "${p.surface}"
    set -g @color_bg2 "${p.border}"
    set -g @color_bg3 "${p.divider}"
    # Text
    set -g @color_fg1 "${p.fgSoft}"
    # Accents
    set -g @color_green "${p.olive}"
    set -g @color_yellow "${p.gold}"
    # Ember ramp — the status bar heats up along these three, cold to blazing
    set -g @color_ash "${p.ash}"
    set -g @color_ember_dim "${p.accentDim}"
    set -g @color_ember "${p.accent}"
    # Command-prompt cursor (tmux >= 3.5). A colour option, not a style, so
    # it can't reference the @vars above; the hex comes straight from here.
    set -g prompt-cursor-colour "${p.accent}"
  '';

  # Plugin *options* are plain `set -g @…` and cost nothing, so they stay up
  # top where they read like configuration. The plugins' own entrypoints are
  # loaded at the very bottom instead — see loadPlugins.
  pluginOptions = ''
    # ── tmux-resurrect ──
    set -g @resurrect-strategy-vim 'session'
    set -g @resurrect-strategy-nvim 'session'
    set -g @resurrect-processes 'vim nvim ssh npm ~ipython'
    set -g @resurrect-capture-pane-contents 'on' # Restore pane contents

    # ── tmux-continuum ──
    set -g @continuum-restore 'on' # Continuum auto restore
    set -g @continuum-save-interval '5' # Save every 5 mins

    # ── tmux-floax ──
    set -g @floax-bind 'F'
    set -g @floax-width '90%'
    set -g @floax-height '90%'
    # floax passes these to its popup as -S/-s, overriding popup-border-style
    # and popup-style from tmux.conf (its defaults are magenta and blue)
    set -g @floax-border-color '${p.accent}'
    set -g @floax-text-color '${p.fg}'
  '';

  # continuum with two calls cut out of its entrypoint (the functions stay):
  # - handle_tmux_automatic_start: with @continuum-boot on it writes
  #   ~/.config/systemd/user/tmux.service once and never updates it; with it
  #   off it runs `systemctl --user disable tmux.service` on every server
  #   start. That unit started its own server on /tmp/tmux-1000/default,
  #   while HM's secureSocket puts the shells' server under $XDG_RUNTIME_DIR,
  #   so it ran a second server nobody attached to.
  # - add_resurrect_save_interpolation: prepends `#(continuum_save.sh)` to
  #   status-right, which re-runs the script on every status redraw.
  #   status-daemon.nu calls it instead (see continuumSave).
  # The count check fails the build if upstream renames either call.
  continuum = pkgs.tmuxPlugins.continuum.overrideAttrs (o: {
    postPatch = (o.postPatch or "") + ''
      calls='^[[:space:]]+(handle_tmux_automatic_start|add_resurrect_save_interpolation)$'
      [ "$(grep -cE "$calls" continuum.tmux)" = 2 ]
      sed -i -E "/$calls/d" continuum.tmux
    '';
  });

  plugins = [
    pkgs.tmuxPlugins.resurrect
    continuum
    pkgs.tmuxPlugins.tmux-floax
  ];

  # With the status-right interpolation patched out, nothing in continuum
  # calls its save script any more — status-daemon.nu does, once a minute.
  # The script keeps doing its own @continuum-save-interval check, so the
  # save cadence is still 5 minutes.
  continuumSave = "${continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh";

  # The one process that now computes the bar's dynamic segments. See the
  # header of status-daemon.nu for the measurements that motivated it.
  #
  # writeNuBin runs it under `nu --no-config-file`, so none of the shell's
  # own startup (starship, atuin, zoxide, television) is in the picture —
  # this is nushell the scripting language, not the interactive shell from
  # ../terminal/nushell.nix. The tmux binary is handed over as argv rather
  # than found on PATH, so the feeder always drives the same tmux the rest
  # of this module was built against.
  statusDaemon = pkgs.writers.writeNuBin "tmux-status-daemon" (
    builtins.readFile ./status-daemon.nu
  );

  # Loaded last, and in the background. `programs.tmux.plugins` would emit a
  # bare `run-shell <plugin>.tmux` per plugin *above* extraConfig, which gets
  # both of those wrong:
  #
  # 1. Ordering. The plugins read the @options in pluginOptions when they
  #    load (floax binds @floax-bind then), so they have to run after them.
  #
  # 2. Cost. Each entrypoint is a bash script that talks back to the server
  #    over dozens of synchronous show-option/set-option round-trips: ~236ms
  #    added to every cold server start (250ms -> 14ms once moved off the
  #    critical path).
  #
  # One chained `-b` rather than one `-b` per plugin, because the order still
  # matters between them: continuum reads @resurrect-restore-script-path,
  # which resurrect only sets when it itself loads.
  loadPlugins = ''

    run-shell -b '${lib.concatMapStringsSep "; " (pl: pl.rtp) plugins}; ${statusDaemon}/bin/tmux-status-daemon #{socket_path} ${continuumSave} ${lib.getExe config.programs.tmux.package}'
  '';
in
{
  home.packages = with pkgs; [ serpl ];
  programs.tmux = {
    enable = true;
    # vi keys in copy mode and in the command prompt (mode-keys/status-keys)
    keyMode = "vi";
    # Windows and panes count from 1, not 0
    baseIndex = 1;
    mouse = true;
    # Forward focus events so nvim gets FocusGained/FocusLost (autoread, gitsigns)
    focusEvents = true;
    # Size a window to the largest client looking at *that window*, not the
    # largest client attached to the session
    aggressiveResize = true;
    # The default scrollback is a measly 2000 lines
    historyLimit = 50000;
    # Small nonzero value: 0 makes tmux misread a lone Esc in escape sequences over ssh
    escapeTime = 10;
    # Apps inside tmux should see tmux's own terminfo; truecolor/extkeys are
    # granted via terminal-features in tmux.conf, independent of the outer terminal.
    terminal = "tmux-256color";
    # Order matters here — see loadPlugins.
    # Too look at some point, i3 style automatic layouts in tmux
    # https://github.com/jabirali/tmux-tilish
    extraConfig = pluginOptions + emberColors + builtins.readFile ./tmux.conf + loadPlugins;
  };
}
