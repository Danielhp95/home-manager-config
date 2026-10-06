{
  pkgs,
  lib,
  config,
  ...
}:

let
  palette = import ../../palette;
  p = palette.hash;
  inherit (palette.roles) search;
  # The @color_* variables tmux.conf renders with, from palette/
  emberColors = ''
    # ── Ember palette — GENERATED from palette/ by default.nix ──
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
    # tmux's defaults for these are ANSI names (red, blue, magenta, cyan), and
    # which slot is the accent differs per palette, so they are set from here:
    # prefix-q pane numbers and the clock, then copy mode's search matches
    # (colour is their only cue: the palette's roles.search pair) and mark.
    set -g display-panes-active-colour "${p.accent}"
    set -g display-panes-colour "${p.steel}"
    set -g clock-mode-colour "${p.steel}"
    set -g copy-mode-match-style "bg=${p.${search.match}},fg=${p.bg}"
    set -g copy-mode-current-match-style "bg=${p.${search.current}},fg=${p.bg}"
    set -g copy-mode-mark-style "bg=${p.accent},fg=${p.bg}"
  '';

  # A command line that opens a nix shell, env assignments allowed in front
  # (POSIX ERE). zsh notes the lines that match on their pane, and resurrect
  # restores the saved commands that match.
  nixShellLine = "^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*nix(-shell| develop| shell)( |$)";

  # @resurrect-hook-post-save-layout: rewrites the save file ($1) before
  # resurrect compares it with the previous one.
  resurrectPostSave = pkgs.writeShellScript "resurrect-post-save-layout" ''
    # Nix wrappers exec with a full path as argv[0] (/nix/store/…/bin/yazi), and
    # nixCats adds --cmd source/nix/store/… to nvim. Neither matches a name in
    # the restore list, and both pin a store path. Saved back as `name <args>`.
    sed -i -E 's#\t:(/etc/profiles/per-user/[^/]+|/run/current-system/sw|/nix/store/[^/]+)/bin/#\t:#; s# --cmd source/nix/store/[^ ]*/nvim-setup[.]lua##' "$1"

    # nix-shell and nix develop exec the shell they build, so the pane's process
    # is `bash --rcfile /tmp/nix-shell…` and the command line is gone. A pane
    # whose zsh noted one (programs.zsh.initContent below) is saved as that
    # command, in the directory it ran from: `nix-shell shell.nix` fails in any
    # other. A note on a pane with nothing running (:) is stale.
    noted=$(tmux list-panes -a -f '#{@nix_shell_cmd}' \
      -F $'#{session_name}\t#{window_index}\t#{pane_index}\t#{@nix_shell_dir}\t#{@nix_shell_cmd}')
    [ -n "$noted" ] || exit 0
    awk -F '\t' -v OFS='\t' '
      NR == FNR { dir[$1, $2, $3] = $4; cmd[$1, $2, $3] = $5; next }
      $1 == "pane" && $11 != ":" && ($2, $3, $6) in cmd {
        $8 = ":" dir[$2, $3, $6]; $11 = ":" cmd[$2, $3, $6]
      }
      { print }
    ' <(printf '%s\n' "$noted") "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  '';

  # Plugin options only; the plugins themselves load last (see loadPlugins)
  pluginOptions = ''
    # ── tmux-resurrect ──
    set -g @resurrect-strategy-vim 'session'
    set -g @resurrect-strategy-nvim 'session'
    # claude comes back as --continue: the last conversation in that directory.
    # The last entry (~ makes it a regex) is the nix shells resurrectPostSave saves.
    set -g @resurrect-processes 'vim nvim ssh npm ~ipython yazi "claude->claude --continue" "~${nixShellLine}"'
    set -g @resurrect-capture-pane-contents 'on' # Restore pane contents
    set -g @resurrect-hook-post-save-layout '${resurrectPostSave}'

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

  # continuum minus two calls: handle_tmux_automatic_start manages a
  # tmux.service whose server sits in /tmp, not HM's $XDG_RUNTIME_DIR (an
  # orphaned second server); add_resurrect_save_interpolation adds a #() hook
  # (status-daemon.nu calls the script). The grep fails the build if either moves.
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

  # status-daemon.nu calls this once a minute; the script's own
  # @continuum-save-interval check keeps the saves 5 minutes apart.
  continuumSave = "${continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh";

  # Computes the bar's dynamic segments (see status-daemon.nu). writeNuBin runs
  # it with --no-config-file; tmux comes in as argv, pinning the one built here.
  statusDaemon = pkgs.writers.writeNuBin "tmux-status-daemon" (builtins.readFile ./status-daemon.nu);

  # Last and in the background, not via programs.tmux.plugins (which runs them
  # above extraConfig): they read pluginOptions at load time, and their
  # synchronous round-trips cost ~236ms of a cold start. One chained -b keeps
  # the order: continuum needs the script paths resurrect sets when it loads.
  loadPlugins = ''

    run-shell -b '${
      lib.concatMapStringsSep "; " (pl: pl.rtp) plugins
    }; ${statusDaemon}/bin/tmux-status-daemon #{socket_path} ${continuumSave} ${lib.getExe config.programs.tmux.package}'
  '';
in
{
  home.packages = [ pkgs.serpl ];
  # A switch that changes the config (a palette switch does) reloads it in the
  # running server, as `prefix r` would. The socket is under XDG_RUNTIME_DIR,
  # which the activation service does not have set.
  xdg.configFile."tmux/tmux.conf".onChange = ''
    TMUX_TMPDIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
      ${lib.getExe config.programs.tmux.package} source-file ${config.xdg.configHome}/tmux/tmux.conf 2>/dev/null || true
  '';

  # The noting half of resurrectPostSave's nix shells. Only a pane's own shell
  # does it (a child of the tmux server, whose pid is in $TMUX): a nix shell
  # opened in nvim's :terminal must not replace the pane's nvim.
  programs.zsh.initContent = ''
    if [[ -n $TMUX_PANE && $PPID == ''${''${TMUX#*,}%%,*} ]]; then
      # $3 is the line about to run, aliases expanded. The save file is one
      # tab-separated line per pane, hence no newlines or tabs.
      __nix_shell_note () {
        [[ $3 =~ '${nixShellLine}' && $3 != *[$'\n\t']* ]] || return
        tmux set-option -p -t $TMUX_PANE @nix_shell_dir $PWD \; \
          set-option -p -t $TMUX_PANE @nix_shell_cmd $3 2>/dev/null && __nix_shell_noted=1
      }
      # Back at the prompt, so the nix shell has exited
      __nix_shell_forget () {
        [[ -n $__nix_shell_noted ]] || return
        unset __nix_shell_noted
        tmux set-option -pu -t $TMUX_PANE @nix_shell_dir \; \
          set-option -pu -t $TMUX_PANE @nix_shell_cmd 2>/dev/null
      }
      preexec_functions+=(__nix_shell_note)
      precmd_functions+=(__nix_shell_forget)
    fi
  '';

  programs.tmux = {
    enable = true;
    # vi keys in copy mode and in the command prompt (mode-keys/status-keys)
    keyMode = "vi";
    # Windows and panes count from 1, not 0
    baseIndex = 1;
    mouse = true;
    # Forward focus events so nvim gets FocusGained/FocusLost (autoread, gitsigns)
    focusEvents = true;
    # Size windows to the clients viewing them, not to every client of the session
    aggressiveResize = true;
    # The default scrollback is 2000 lines
    historyLimit = 50000;
    # Small nonzero value: 0 makes tmux misread a lone Esc in escape sequences over ssh
    escapeTime = 10;
    # tmux's own terminfo inside; truecolor/extkeys come from terminal-features
    # in tmux.conf
    terminal = "tmux-256color";
    # Order matters here — see loadPlugins.
    extraConfig = pluginOptions + emberColors + builtins.readFile ./tmux.conf + loadPlugins;
  };
}
