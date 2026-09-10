{ pkgs, lib, ... }:
let
  p = (import ../palette.nix).hash;

  # What used to be fifteen substitutions is now three. Upstream grew a theme
  # file and a `ui.max-width` setting (v0.4.19-v0.4.22), so the colour and box
  # width patches moved into config below; what is left are the behaviours that
  # still have no knob. Every replacement is --replace-fail: if upstream moves
  # a line, the build breaks loudly instead of silently reverting.
  #
  # All three re-applied unchanged across the v0.5.x -> v0.6.3 -> v0.7.0
  # bumps, both of which reworked this same file heavily (v0.6: pty.Open +
  # Setctty instead of pty.Start, an alt-screen guard, the watchdog cwd relay;
  # v0.7: word motion on ctrl+arrow, core.navigate-closed, a deferred-draw
  # repaint queue). The anchors and their surrounding control flow were
  # re-read against each new tree, not assumed.
  iris = pkgs.iris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ### Description column: grow it with the box #############################
      # ui.max-width sizes the box, but descW is still `descW := 24` regardless
      # of how wide the box ended up, so the extra room all goes to the command
      # column. inner is in scope here (boxWidth - 2). 24 stays the floor.
      substituteInPlace integration/overlay.go \
        --replace-fail 'descW := 24' 'descW := max(24, inner/4)'

      ### Select key: hand it back to the shell when no menu is open ###########
      # keybindings.select is configurable now, but the swallow is not fixed —
      # as of v0.7.0 it is deliberate: the matched-key branch ends in
      # `i += consumed - 1; continue` sitting *outside* the
      # `if overlay.IsVisible()` block, now with an upstream comment saying it
      # should "always consume the full binding atomically, even when the
      # overlay is hidden". So with the default select = "tab" the key is
      # eaten and never written to the pty even when there is no menu to accept
      # from — fzf-tab and the Tab-Tab television binding stay unreachable.
      # Forwarding the raw bytes when the overlay is hidden restores both.
      # Setting select = "" is not an alternative: config.Load() forces the
      # empty string back to "tab".
      #
      # Deliberately does not set shouldOverlayDraw: IRIS must not redraw over
      # fzf-tab's own output.
      substituteInPlace root/wrapper.go \
        --replace-fail 'if matched, consumed := config.MatchKey(inputSlice[i:], config.Get().Keybindings.SelectSuggestion); matched && config.Get().Keybindings.SelectSuggestion != "" {' 'if matched, consumed := config.MatchKey(inputSlice[i:], config.Get().Keybindings.SelectSuggestion); matched && config.Get().Keybindings.SelectSuggestion != "" { if !overlay.IsVisible() { _, _ = ptmx.Write(inputSlice[i : i+consumed]); i += consumed - 1; continue }'

      ### Ctrl-J / Ctrl-K: move down/up the list, as in nvim, tv and fzf #######
      # keybindings.navigate-up/navigate-down exist now, but pointing them at
      # ctrl+k/ctrl+j would be a downgrade on three counts, so the keys are
      # still added here instead:
      #
      #   1. There is one slot per direction, so config buys Ctrl-J/K only by
      #      giving up the arrows. This adds them *alongside*.
      #   2. handleNavKey's `else if suggestionsEnabled` branch opens the
      #      history list when the overlay is hidden, and its caller's
      #      `continue` swallows the byte either way — so Ctrl-J and Ctrl-K
      #      would stop being zsh's accept-line and kill-line entirely. v0.7.0
      #      softened this but did not remove it: core.navigate-closed = "shell"
      #      now forwards the *configured* nav keys when the menu is closed, and
      #      that is a single global switch — it cannot forward Ctrl-J/K while
      #      still letting the arrows open the history list, which is what this
      #      config wants (see navigate-closed below).
      #   3. The config path matches on every byte with no paste guard, so
      #      newlines inside a pasted block would be eaten as navigate-down.
      #
      # Both guards below are load-bearing and cover exactly (2) and (3).
      # `overlay.IsVisible()` keeps the keys as zsh's own when there is no list
      # to move through; `!inBracketedPaste` keeps a pasted block intact.
      # Terminals send 0x0a for Ctrl-J and 0x0d for Enter, and IRIS puts stdin
      # in raw mode (no ICRNL), so the two stay distinct here even though the
      # enter branch further down accepts either.
      #
      # Falling through is what makes the hidden case correct: 0x0a reaches the
      # enter branch and is forwarded as Enter, and 0x0b reaches the trailing
      # `if !intercepted` write. Neither needs handling here.
      substituteInPlace root/wrapper.go \
        --replace-fail 'var isNavUp, isNavDown bool' 'if overlay.IsVisible() && !inBracketedPaste && (b == 0x0b || b == 0x0a) { navDir := "down"; if b == 0x0b { navDir = "up" }; handleNavKey(navDir); continue }; var isNavUp, isNavDown bool'
    '';
  });
in
# IRIS (Intelligent Real-time Input Suggestion): an IntelliSense-style
# completion overlay. `pkgs.iris` comes from the flake input via overlays in
# flake.nix.
#
# HOW IT WORKS — read this before changing anything here. IRIS is *not* a zsh
# plugin. It is a PTY wrapper: `iris` puts the terminal in raw mode, spawns a
# fresh `zsh` as a child, mirrors your keystrokes into its own buffer, and
# draws the suggestion menu as an inline overlay. Keys it recognises are
# consumed by IRIS and never reach zle; everything else is forwarded to the
# child shell untouched.
#
# Upstream intercepts the select key (Tab by default) unconditionally, even
# with no menu open, which makes fzf-tab and the Tab-Tab television binding
# unreachable. The patch above forwards Tab whenever IRIS has no menu open, so
# both work again. Note the remaining overlap: while the suggestion menu *is*
# up (which is most of the time you're mid-word), Tab accepts IRIS's selection.
# Toggle the menu off to hand the key back. To make Tab always defer to zsh
# instead, set keybindings.select below to something else — ctrl+y, say — and
# the patch stops mattering for Tab.
#
# Menu navigation is patched to accept Ctrl-J / Ctrl-K alongside the arrows, to
# match nvim, television and fzf. They only navigate while the menu is open; the
# rest of the time zsh keeps them (accept-line and kill-line).
#
# Editing mid-line works properly as of v0.7.0 (#156), and needs nothing here
# beyond the line-report hook below: Ctrl/Alt + arrow are forwarded to zsh
# untouched, so backward-word/forward-word are still zsh's, and IRIS follows the
# cursor instead of assuming it sits at the end of the buffer.
#
# This is still wired as an opt-in `i` command rather than upstream's autostart
# hook, which `exec iris`s every interactive zsh. Plain zsh keeps fzf-tab,
# Tab-Tab tv, atuin and autosuggestions exactly as they were.
{
  home.packages = [ iris ];

  # Colours live in their own file since v0.4.22 — config.toml has no [theme]
  # section, `LoadTheme` reads $XDG_CONFIG_HOME/iris/theme.toml directly. Every
  # field is optional and falls back individually, but all nineteen are spelled
  # out here so a palette change can never leave a stray Aura purple behind.
  # The names map onto what upstream's own defaults coloured, which is why the
  # four accent roles below (key, scroll_info, sys_sel, alias_sel) share gold:
  # they were all #a277ff, and only the border wanted to stay quiet.
  #
  # The names have drifted from what they paint, though: the "atuin" source
  # badge added in v0.6.0 is drawn with alias/alias_sel rather than hist/
  # hist_sel (integration/overlay.go's `case "atuin"`), so atuin rows come out
  # in the alias colours. Nothing to add here — upstream still has exactly
  # these nineteen fields, verified against the v0.7.0 tree — but don't read
  # the field names as a source list.
  #
  # IRIS stats this path every second alongside config.toml and hot-reloads, so
  # a rebuild applies to running sessions without restarting them.
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

  # Managed declaratively, so never run `iris config init` / `iris setup` /
  # `iris theme init`: setup prepends `eval "$(iris init zsh)"` to .zshrc, which
  # is a read-only store symlink here, and the init commands would try to write
  # over the two store-managed files. Runtime state (last-used mode) goes to
  # $XDG_DATA_HOME/iris/state.toml, not here, so read-only is safe.
  xdg.configFile."iris/config.toml".text = ''
    [core]
    version = 1

    # Pinned rather than auto-detected: detection walks /proc for the parent
    # shell and silently falls back to bash for anything it doesn't recognise
    # (nushell included).
    shell = "zsh"

    # Remember spec/history mode across sessions
    mode = "last"
    debug = false

    # Upstream default is true, which rewrites the line as you type: `ls ` +
    # space becomes `eza -lahF --git `, because IRIS scrapes `alias -- ls=...`
    # out of .zshrc. Off keeps the buffer as typed; the menu still resolves
    # aliases for its suggestions either way.
    expand-alias = false

    # On Enter, run what is typed rather than what is highlighted. True would
    # execute the suggestion instead — so typing `nvim ~/.conf` and hitting
    # Enter would run `nvim ~/.config`. Upstream's default, and the safe one.
    auto-execute = false

    # History mode: 0 = shell history file, 1 = atuin only, 2 = both merged.
    # New in v0.6.0. This is the setting that matters most on this machine,
    # because atuin is where the history actually lives: ~/.config/zsh/
    # .zsh_history holds ~9k lines, while atuin's history.db holds ~159k. Mode
    # 0 was therefore searching a small fraction of what has ever been typed
    # here. 2 rather than 1 so a command run in a non-atuin shell (a plain
    # `zsh -f`, a recovery session) is still reachable.
    #
    # IRIS opens the DB read-only and re-reads it when its mtime changes, so
    # it never contends with atuin's daemon over the write lock.
    atuin-history = 2

    # Left empty on purpose. IRIS resolves $XDG_DATA_HOME/atuin/history.db and
    # falls back to ~/.local/share/atuin/history.db, which is exactly where the
    # atuin module in ./default.nix leaves it — spelling the path out here
    # would just duplicate atuin's own default and rot if either side moves.
    atuin-db-path = ""

    # When a command has no completion spec, IRIS runs `<binary> __complete` to
    # see whether it is a cobra CLI. Configurable since v0.6.1, and worth
    # knowing the shape of: this executes binaries off $PATH as you type.
    #
    # Left on because the same release added a real gate — spec/
    # cobra_complete.go now reads the Go build info out of the binary and only
    # probes if it genuinely imports spf13/cobra, on top of the pre-existing
    # setsid isolation and 300ms timeout. Shell scripts (sie-vpn-connect,
    # davinci, the writeShellScriptBin wrappers) have no build info and are
    # never probed at all. Set false if that trade ever stops being worth it.
    cobra-probe-enabled = true

    # What the navigate keys do while the menu is *closed*. New in v0.7.0, and
    # pinned rather than left implicit because it decides the fate of the arrow
    # keys inside an IRIS session:
    #
    #   "history" — open IRIS's own merged (atuin + shell) history list.
    #   "shell"   — forward the key to zsh, i.e. up-line-or-history.
    #
    # Upstream's default, and kept: with atuin-history = 2 that list is the
    # ~159k-entry atuin DB rather than the ~9k-line zsh histfile, so it is
    # strictly the better history here. The cost is that zsh's own
    # up-line-or-history is unreachable while inside IRIS — acceptable because
    # atuin already runs --disable-up-arrow (terminal/default.nix), so Up at a
    # plain prompt is only ever zsh's small file anyway. Switch to "shell" if
    # the displacement ever grates; Ctrl-J/K still navigate the open menu
    # either way, which is what makes the switch cheap.
    navigate-closed = "history"

    [ui]
    style = "modern"

    # A three-mode option since v0.7.0, no longer a bool: 0 = off, 1 = on,
    # 2 = "individual" — ghost text with the menu box suppressed until
    # shift+tab asks for it. Written as the integer rather than `true` because
    # the bool spelling only survives as a back-compat branch in
    # GhostTextMode.UnmarshalTOML. 1 keeps what was here; 2 is the one to try
    # if the box ever feels like too much furniture.
    ghost-text = 1

    hidden-files = false
    max-suggestions = 100

    # Only actually obeyed since v0.7.0 (#104) — before that the box sized
    # itself off max-suggestions and this was decorative, so expect a shorter
    # menu than v0.6 drew.
    max-height = 12

    nerd-fonts = true

    # A share of the terminal, new in v0.7.0, re-resolved on every draw
    # (Width.Resolve) rather than once at load. Replaces the old fixed 200,
    # which was a cap chosen to mean "fill the terminal, but stop there on an
    # ultrawide"; a percentage says that directly. The description column still
    # does not follow it on its own — see the descW patch above.
    #
    # The quotes are load-bearing. Width.UnmarshalTOML accepts an int64 or a
    # string, so a bare 80% is not valid TOML at all — and IRIS answers a parse
    # error by discarding this *entire* file and running on upstream defaults.
    # Measured, with the quotes off: shell = "" (detection back on, which falls
    # back to bash), expand-alias = true, atuin-history = 0, toggle-mode =
    # "ctrl+r" — every deliberate choice in this module silently undone, with
    # nothing but one line on stderr at startup to say so. Worth remembering for
    # any value edited here, not just this one.
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

    # Not the qwen3-coder:30b ollama.nix loads for open-webui/opencode: the
    # budget here is debounce 400ms + a 2500ms timeout on a request fired
    # mid-typing, which is a time-to-first-token problem, not a tok/s one.
    # There is no small qwen3-coder to prefer — that repo stops at 30b.
    #
    # `-instruct-` is load-bearing. Qwen3 ships split lines: -instruct-2507
    # emits no reasoning, while -thinking-2507 and the bare qwen3:4b do, which
    # would blow the deadline and violate the system prompt's "no explanation,
    # no markdown, no fences". Spelled out rather than the qwen3:4b-instruct
    # alias (same digest today) so an upstream repoint cannot swap that in.
    [ai.providers.ollama]
    endpoint = "http://localhost:11434/v1/chat/completions"
    model = "qwen3:4b-instruct-2507-q4_K_M"
    timeout_ms = 2500
  '';

  programs.zsh = {
    shellAliases.i = "iris";

    # mkBefore so this lands ahead of the plugin sourcing: both opt-outs below
    # are read by the plugins at load time, which makes the result independent
    # of how home-manager happens to order the rest of .zshrc.
    initContent = lib.mkBefore ''
      # Only true in the zsh that IRIS spawned as its child. The $PPID test is
      # load-bearing under tmux and not just belt-and-braces: IRIS_PID/IRIS_FD
      # are plain environment variables, so a tmux server started from inside
      # an IRIS session hands them to every pane it later spawns. Those panes
      # are not IRIS children — their parent is the tmux server, and the fd is
      # long closed — so without this they would silently drop autosuggestions
      # and autopair and install an IPC hook writing into nothing.
      #
      # Upstream rewrote its own version of this guard in v0.6.x (#120): it no
      # longer greps $PPID for "tmux" but unsets the vars when $PPID differs
      # from $IRIS_PID *and* the tty differs from a new IRIS_TTY export. That
      # is looser than what is here — it needs both to fail — so the plain
      # $PPID == $IRIS_PID test below still covers strictly more cases and is
      # kept (verified: IRIS execs the child shell directly, so the two match).
      if [[ -n "$IRIS_PID" && -n "$IRIS_FD" && "$PPID" == "$IRIS_PID" ]]; then
        # Two ghost texts on one line garbles both. IRIS draws its own (and is
        # the AI-aware one), so zsh's yields. The plugin tests for the
        # variable's existence, not its value.
        typeset -g _ZSH_AUTOSUGGEST_DISABLED

        # IRIS applies a suggestion by writing Ctrl-U + the full command into
        # the pty, i.e. as if typed. autopair would then "helpfully" close any
        # quote or paren in it, so the executed command differs from the one
        # shown. Inhibit its keybindings for this session only.
        AUTOPAIR_INHIBIT_INIT=1

        # IPC back to the wrapper, equivalent to the hook half of
        # `iris init zsh` (root/init.go) minus its autostart block, which we
        # deliberately don't want. Inlined rather than eval'd to keep a
        # subprocess out of every zsh startup. Re-check on upstream bumps.
        #
        # line-pre-redraw feeds zle's authoritative buffer to IRIS, which
        # otherwise only has its own naive keystroke mirror — this is what
        # keeps the overlay honest when a widget rewrites the line.
        #
        # The payload is a protocol as of v0.7.0 (#156):
        # "IRIS_LINE:<chars left of cursor>:<whole buffer>" (zsh's ''${#LBUFFER}
        # is a character count, and Go counts runes to match). Sending a bare
        # $LBUFFER, as this did before, still parses — parseLineReport treats an
        # unprefixed payload as the whole line with the cursor at its end — but
        # that is exactly the bug the prefix fixed: everything right of the
        # cursor was invisible to IRIS, so completing mid-line truncated the
        # tail, and ctrl+left/right word motion had no cursor to move.
        #
        # IRIS_CWD keeps IRIS's idea of the directory in sync: it resolves
        # path completions itself, from its own cwd, which never moves because
        # the `cd` happens in the child shell. chpwd covers interactive cds,
        # precmd covers the rest (a script that cds, a subshell popping back).
        #
        # This hook earns more than completions since v0.6.x: #129 made the
        # wrapper chdir to each IRIS_CWD it receives, and #143 relays it on to
        # the outer watchdog process over a dedicated fd. Anything that locates
        # a shell by reading its pane's foreground process — tmux's
        # pane_current_path, most notably — therefore only tracks `cd` inside
        # an IRIS session because these lines are here. Dropping them would now
        # strand tmux at the directory the session started in.
        # The exit code on IRIS_CMD_STOP feeds the rule-based "retry the last
        # failure" suggestion, which runs with ai.enabled = false. The wrapper
        # accepts a bare IRIS_CMD_STOP too, so both are additive.
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
      fi
    '';
  };

  # Nushell gets the binary on PATH, but IRIS cannot wrap it: there is no
  # nushell adapter (integration/shell/adapter.go has zsh/bash/fish and
  # defaults everything else to bash), and core.shell validation rejects "nu"
  # outright. Even with an adapter it would misbehave — IRIS clears the line
  # with Ctrl-U, which isn't kill-whole-line in reedline's vi insert mode, and
  # it eats Esc for "hide menu", which vi mode needs. So `i` here is explicit
  # about dropping into a zsh-backed IRIS session rather than pretending.
  programs.nushell.extraConfig = ''
    # IRIS doesn't support nushell; this starts an IRIS session running zsh.
    # Exit it to come back to nu.
    def --wrapped i [...args: string] {
      ^iris --shell zsh ...$args
    }
  '';
}
