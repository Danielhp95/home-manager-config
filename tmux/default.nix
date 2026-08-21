{ pkgs, lib, config, ... }:

let
  p = (import ../palette.nix).hash;
  # The @color_* variables tmux.conf renders with, generated from palette.nix
  # so tmux, starship and the rest of the system share one source of truth.
  # (tmux.conf used to carry near-identical local copies of these values.)
  emberColors = ''
    # ── Ember palette — GENERATED from palette.nix by default.nix ──
    # Surfaces
    set -g @color_bg0 "${p.bg}"
    set -g @color_bg1 "${p.surface}"
    set -g @color_bg2 "${p.border}"
    set -g @color_bg3 "${p.divider}"
    # Text
    set -g @color_fg0 "${p.fg}"
    set -g @color_fg1 "${p.fgSoft}"
    set -g @color_fg2 "${p.fgDim}"
    # Accents
    set -g @color_blue "${p.steel}"
    set -g @color_cyan "${p.sage}"
    set -g @color_green "${p.olive}"
    set -g @color_yellow "${p.gold}"
    set -g @color_red "${p.accent}"
    set -g @color_purple "${p.mauve}"
    # Ember ramp — the status bar heats up along these four, cold to blazing
    set -g @color_ash "${p.ash}"
    set -g @color_ember_dim "${p.accentDim}"
    set -g @color_ember "${p.accent}"
    set -g @color_ember_hot "${p.accentBright}"
    # Legacy names kept so nothing dangles; mapped to nearest palette hue
    set -g @color_orange "${p.ash}"
    set -g @color_pink "${p.mauve}"
    set -g @color_lavender "${p.mauve}"
    set -g @color_sapphire "${p.steel}"
    set -g @color_teal "${p.sage}"
    set -g @color_maroon "${p.mauve}"
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
    set -g @resurrect-auto-restore 'on'

    # ── tmux-continuum ──
    set -g @continuum-boot 'on'
    set -g @continuum-restore 'on' # Continuum auto restore
    set -g @continuum-save-interval '5' # Save every 5 mins

    # ── tmux-floax ──
    set -g @floax-bind 'F'
    set -g @floax-width '90%'
    set -g @floax-height '90%'
  '';

  plugins = with pkgs.tmuxPlugins; [ resurrect continuum tmux-floax ];

  # continuum drives its autosave *entirely* from the `#(continuum_save.sh)`
  # interpolation it prepends to status-right, so taking that off the render
  # path means something else has to call the script — status-daemon.nu does,
  # once a minute. The script keeps doing its own @continuum-save-interval
  # check, so the save cadence is still 5 minutes.
  continuumSave =
    "${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh";

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
  # 1. Ordering. continuum's load step prepends `#(continuum_save.sh)` to
  #    status-right — and the status bar in tmux.conf, being configured after
  #    it, overwrote the whole option and silently disabled the 5-minute
  #    auto-save. (Symptom: @continuum-save-last-timestamp frozen at the
  #    server's start time and save files days old.) Loading after the bar is
  #    built keeps the interpolation — which the feeder chained on below then
  #    strips deliberately, having taken over calling the save script itself.
  #    Same reason the strip can't just live in tmux.conf: continuum has to
  #    have run first, and it runs from here.
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
    keyMode = "vi";
    # Apps inside tmux should see tmux's own terminfo; truecolor/extkeys are
    # granted via terminal-features in tmux.conf, independent of the outer terminal.
    terminal = "tmux-256color";
    # Order matters here — see loadPlugins.
    # Too look at some point, i3 style automatic layouts in tmux
    # https://github.com/jabirali/tmux-tilish
    extraConfig = pluginOptions + emberColors + builtins.readFile ./tmux.conf + loadPlugins;
  };
}
