{ pkgs, lib, ... }:
let
  p = (import ../palette).hash;

  # Created under this exact name by ollama-iris-model.service
  # (../non_home_manager_config/ollama.nix).
  aiModel = "iris-qwen3-4b";

  # Behaviour with no config knob. --replace-fail breaks the build if upstream
  # moves an anchor; re-read the control flow around each one on a bump.
  iris = pkgs.iris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ### Description column: grow it with the box #############################
      # descW is a fixed 24 however wide ui.max-width makes the box; 24 stays
      # the floor.
      substituteInPlace integration/overlay.go \
        --replace-fail 'descW := 24' 'descW := max(24, inner/4)'

      ### Select key: hand it back to the shell when no menu is open ###########
      # Upstream consumes the select key (Tab) even with the menu hidden, so
      # fzf-tab and Tab-Tab tv never see it; select = "" is forced back to
      # "tab". No shouldOverlayDraw: IRIS must not redraw over fzf-tab.
      substituteInPlace root/wrapper.go \
        --replace-fail 'if matched, consumed := config.MatchKey(inputSlice[i:], config.Get().Keybindings.SelectSuggestion); matched && config.Get().Keybindings.SelectSuggestion != "" {' 'if matched, consumed := config.MatchKey(inputSlice[i:], config.Get().Keybindings.SelectSuggestion); matched && config.Get().Keybindings.SelectSuggestion != "" { if !overlay.IsVisible() { _, _ = ptmx.Write(inputSlice[i : i+consumed]); i += consumed - 1; continue }'

      ### Ctrl-J / Ctrl-K: move down/up the list, as in nvim, tv and fzf #######
      # Not navigate-up/down: one key per direction (the arrows would go), no
      # paste guard, and with the menu closed it would swallow zsh's
      # accept-line/kill-line. Hence the IsVisible and bracketed-paste guards;
      # with no menu, 0x0a falls through as Enter and 0x0b to the pty.
      substituteInPlace root/wrapper.go \
        --replace-fail 'var isNavUp, isNavDown bool' 'if overlay.IsVisible() && !inBracketedPaste && (b == 0x0b || b == 0x0a) { navDir := "down"; if b == 0x0b { navDir = "up" }; handleNavKey(navDir); continue }; var isNavUp, isNavDown bool'
    '';
  });
in
# IRIS: an IntelliSense-style completion overlay (pkgs.iris, from the flake
# input). A PTY wrapper, not a zsh plugin: it runs zsh as a child and eats the
# keys it recognises before zle sees them; while its menu is open, Tab
# accepts the suggestion. Opt-in via `i`, not upstream's autostart hook.
{
  home.packages = [ iris ];

  # All 19 theme fields, so no upstream default colour survives. The names
  # don't match what they paint (atuin rows use alias/alias_sel). Running
  # sessions hot-reload this file.
  xdg.configFile."iris/theme.toml".text = ''
    border = "${p.border}"
    accent = "${p.accent}"
    muted = "${p.muted}"
    text = "${p.fg}"
    text_sel = "${p.fg}"
    key = "${p.gold}"
    match = "${p.accent}"
    desc = "${p.fgDim}"
    desc_sel = "${p.fg}"
    sel_bg = "${p.surface}"
    sel_text = "${p.bg}"
    scroll_info = "${p.gold}"
    ghost_text = "${p.muted}"
    sys = "${p.bgAlt}"
    sys_sel = "${p.gold}"
    hist = "${p.bgAlt}"
    hist_sel = "${p.accent}"
    alias = "${p.bgAlt}"
    alias_sel = "${p.gold}"
  '';

  # Never run `iris config init`, `iris setup` or `iris theme init`: they write
  # over these store files and .zshrc. State lives in $XDG_DATA_HOME/iris.
  xdg.configFile."iris/config.toml".text = ''
    [core]
    version = 1

    # Pinned: auto-detection falls back to bash for unknown parents (nushell).
    shell = "zsh"

    # Remember spec/history mode across sessions
    mode = "last"
    debug = false

    # Off: when on, IRIS expands aliases as you type (`ls ` turns into `eza …`).
    expand-alias = false

    # Enter runs what is typed, not the highlighted suggestion.
    auto-execute = false

    # 0 = shell histfile, 1 = atuin, 2 = both. atuin holds most of the history;
    # 2 also covers commands from non-atuin shells. The DB is opened read-only.
    atuin-history = 2

    # Empty: IRIS finds atuin's default $XDG_DATA_HOME/atuin/history.db.
    atuin-db-path = ""

    # Runs `<binary> __complete` for commands without a spec, but only on
    # binaries whose Go build info imports spf13/cobra (setsid, 300ms timeout).
    cobra-probe-enabled = true

    # With the menu closed, Up/Down open IRIS's merged history list ("shell"
    # hands them to zsh). Ctrl-J/K navigate the open menu either way.
    navigate-closed = "history"

    [ui]
    style = "modern"

    # 0 = off, 1 = on, 2 = ghost text only until shift+tab. An int, not a bool.
    ghost-text = 1

    hidden-files = false
    max-suggestions = 100

    max-height = 12

    nerd-fonts = true

    # Share of the terminal width; descW follows it only via the patch above.
    # The quotes matter: a bare 80% is invalid TOML, and a parse error makes
    # IRIS silently drop this whole file and run on upstream defaults.
    max-width = "80%"

    [git]
    filter-active-branch = true
    deduplicate-branches = true

    [updater]
    check-on-startup = false
    channel = "stable"
    check-interval = "24h"
    auto-update = 0

    [zoxide]
    extend-cd = true

    [keybindings]
    toggle-mode = "ctrl+o"
    toggle-menu = "shift+tab"
    select = "tab"
    navigate-up = "up"
    navigate-down = "down"
    navigate-right = "right"

    [ai]
    enabled = true
    provider = "ollama"
    debounce_ms = 400
    min_interval_ms = 1000

    [ai.suggest_on_empty]
    enabled = false
    debounce_ms = 800
    min_interval_ms = 5000

    # A small model, not the qwen3-coder:30b ollama.nix also loads: the budget
    # is time-to-first-token mid-typing. ${aiModel} bakes num_ctx 4096 into
    # qwen3:4b-instruct-2507 (see ollama.nix), since this endpoint ignores
    # num_ctx and keep_alive in the request. Keep `-instruct-`: thinking
    # variants emit reasoning and miss the deadline. timeout_ms must outlast a
    # cold model load, or ollama aborts the load when IRIS hangs up.
    [ai.providers.ollama]
    endpoint = "http://localhost:11434/v1/chat/completions"
    model = "${aiModel}"
    timeout_ms = 4000
  '';

  programs.zsh = {
    shellAliases.i = "iris";

    # mkBefore: the plugin opt-outs below must be set before the plugins load.
    initContent = lib.mkBefore ''
      # Drop IRIS_* vars that belong to another terminal (upstream's guard from
      # `iris init zsh`). With IRIS_PID set, `iris` SIGUSR1s that pid to reload
      # it, killing that session's shell, or whatever process now owns the pid.
      # Upstream leaves IRIS_WATCHDOG_CWD_FD set; it is dropped here too.
      if [[ -n "$IRIS_PID" && "$PPID" != "$IRIS_PID" && "$TTY" != "$IRIS_TTY" ]]; then
        unset IRIS_PID IRIS_IS_CHILD IRIS_FD IRIS_TTY IRIS_WATCHDOG_CWD_FD
      fi

      # Only in the zsh IRIS spawned: panes of a tmux server started inside IRIS
      # inherit IRIS_PID/IRIS_FD too, but their parent is the tmux server.
      if [[ -n "$IRIS_PID" && -n "$IRIS_FD" && "$PPID" == "$IRIS_PID" ]]; then
        # IRIS draws its own ghost text, so zsh-autosuggestions yields (the
        # plugin only checks that this variable exists).
        typeset -g _ZSH_AUTOSUGGEST_DISABLED

        # IRIS applies a suggestion by typing it into the pty; autopair would
        # close its quotes and parens a second time.
        AUTOPAIR_INHIBIT_INIT=1

        # The hook half of `iris init zsh` (root/init.go), minus its autostart;
        # re-diff it on upstream bumps. IRIS_LINE carries the cursor offset
        # with the buffer (mid-line completion needs both), IRIS_CWD keeps
        # IRIS's path completions and tmux's pane_current_path following `cd`,
        # and the IRIS_CMD_STOP exit code feeds the retry-last-failure hint.
        _iris_send_lbuffer() { print -u $IRIS_FD -N -r -- "IRIS_LINE:''${#LBUFFER}:$BUFFER" 2>/dev/null }
        _iris_sync_cwd()     { print -u $IRIS_FD -N -r -- "IRIS_CWD:$PWD" 2>/dev/null }
        _iris_precmd()       {
          local iris_exit_code=$?
          _iris_sync_cwd
          print -u $IRIS_FD -N -r -- "IRIS_CMD_STOP:$iris_exit_code" 2>/dev/null
        }
        _iris_preexec()      { print -u $IRIS_FD -N -r -- "IRIS_CMD_START" 2>/dev/null }

        autoload -Uz add-zle-hook-widget add-zsh-hook
        add-zle-hook-widget line-pre-redraw _iris_send_lbuffer
        add-zsh-hook precmd _iris_precmd
        add-zsh-hook preexec _iris_preexec
        add-zsh-hook chpwd _iris_sync_cwd

        # Keep the model warm while IRIS is in use: each keystroke cancels the
        # request, and a cancelled cold load is aborted. IRIS's endpoint can't
        # set keep_alive but refreshes the one a model was loaded with, so a
        # native 30m load is re-sent (at most every 5 min, in the background)
        # to survive evictions and ollama restarts.
        zmodload -F zsh/datetime p:EPOCHSECONDS
        typeset -gi _iris_ai_warmed_at=0
        _iris_ai_warm() {
          (( EPOCHSECONDS - _iris_ai_warmed_at < 300 )) && return
          _iris_ai_warmed_at=$EPOCHSECONDS
          ${pkgs.curl}/bin/curl -s -m 60 http://127.0.0.1:11434/api/generate \
            -d '{"model":"${aiModel}","keep_alive":"30m"}' >/dev/null 2>&1 &!
        }
        add-zsh-hook precmd _iris_ai_warm
      fi
    '';
  };

  # IRIS can't wrap nushell (no adapter; core.shell rejects "nu"), so `i` in nu
  # starts a zsh-backed session.
  programs.nushell.extraConfig = ''
    # IRIS running zsh; exit it to return to nu.
    def --wrapped i [...args: string] {
      ^iris --shell zsh ...$args
    }
  '';
}
