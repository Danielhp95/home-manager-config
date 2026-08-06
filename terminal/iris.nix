{ pkgs, lib, ... }:
let
  p = (import ../palette.nix).hash;

  # What used to be fifteen substitutions is now two. Upstream grew a theme
  # file and a `ui.max-width` setting (v0.4.19-v0.4.22), so the colour and box
  # width patches moved into config below; what is left are the two behaviours
  # that still have no knob. Every replacement is --replace-fail: if upstream
  # moves a line, the build breaks loudly instead of silently reverting.
  iris = pkgs.iris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ### Description column: grow it with the box #############################
      # ui.max-width sizes the box, but descW is still `descW := 24` regardless
      # of how wide the box ended up, so the extra room all goes to the command
      # column. inner is in scope here (boxWidth - 2). 24 stays the floor.
      substituteInPlace integration/overlay.go \
        --replace-fail 'descW := 24' 'descW := max(24, inner/4)'

      ### Select key: hand it back to the shell when no menu is open ###########
      # keybindings.select is configurable now, but the swallow is not fixed:
      # the matched-key branch ends in `i += consumed - 1; continue`, which sits
      # *outside* the `if overlay.IsVisible()` block, so with the default
      # select = "tab" the key is consumed and never written to the pty even
      # when there is no menu to accept from — fzf-tab and the Tab-Tab
      # television binding stay unreachable. Forwarding the raw bytes when the
      # overlay is hidden restores both. Setting select = "" is not an
      # alternative: config.Load() forces the empty string back to "tab".
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
      #      would stop being zsh's accept-line and kill-line entirely.
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

    [ui]
    style = "modern"
    ghost-text = true
    hidden-files = false
    max-suggestions = 100
    max-height = 12
    nerd-fonts = true

    # Was a hardcoded `const boxWidth = 76`, which left roughly 41 columns for
    # the command before truncation; configurable since v0.4.19. Upstream
    # clamps this down to the terminal width (floor 40), so it reads as a cap
    # rather than a size: 200 means "fill the terminal, but stop there on an
    # ultrawide". Narrow terminals are unaffected. The description column does
    # not follow this on its own — see the descW patch above.
    max-width = 200

    [git]
    filter-active-branch = true
    deduplicate-branches = true

    [updater]
    # Nix owns the binary. Left on, IRIS hits the GitHub releases API on every
    # launch, and `iris update` runs upstream's install.sh, dropping an
    # unmanaged binary in ~/.local/bin that would shadow the store one.
    check-on-startup = false
    channel = "stable"
    check-interval = "24h"

    [keybindings]
    # Enter and Ctrl-A,E,L,U,W,C are still hardcoded in the input pump, as is
    # the Ctrl-J/Ctrl-K navigation patched in above (see the note there for why
    # it is not expressed as navigate-up/navigate-down here).
    #
    # toggle-mode is ctrl+r upstream, which would shadow atuin for the whole
    # session. Moved to ctrl+o (zsh's accept-line-and-down-history, unused
    # here) so Ctrl-R falls through to the child shell and stays atuin
    # everywhere. ctrl+o is also television's toggle_preview, but that is
    # inside tv's own TUI, so the two never see the same keypress.
    toggle-mode = "ctrl+o"

    # The one key still taken from zle: this shadows reverse-menu-complete,
    # which matters little since fzf-tab replaces the completion menu anyway.
    # Set it to "ctrl+space" (zsh's set-mark-command) if you'd rather leave
    # every zsh completion key untouched; the footer hint follows the setting.
    toggle-menu = "shift+tab"

    # Accept the highlighted suggestion. Kept on Tab, which the patch above
    # makes safe: with no menu open Tab reaches zsh and fzf-tab. Point this at
    # ctrl+y to give Tab back to zsh unconditionally.
    select = "tab"

    # Arrows. Note what these now do when *no* menu is open: rather than
    # falling through to zsh, they open IRIS's own history list
    # (handleNavKey's hidden-overlay branch, new in v0.4.19). Inside an IRIS
    # session that displaces zsh's up-line-or-history — atuin is unaffected,
    # it runs with --disable-up-arrow.
    navigate-up = "up"
    navigate-down = "down"

    # Accept the ghost-text completion. Was hardcoded to Right until v0.4.21.
    navigate-right = "right"

    [ai]
    # Off until a provider is actually reachable. Flipping this to true is the
    # only edit needed — see the note in the module header comment.
    enabled = false
    provider = "ollama"
    debounce_ms = 400
    min_interval_ms = 1000

    # Suggest a next command on an *empty* prompt. The rule-based half (retry
    # last failure, continue a rebase, `git diff` after `git status`) runs even
    # with ai.enabled = false; this switch only gates the LLM half.
    [ai.suggest_on_empty]
    enabled = false
    debounce_ms = 800
    min_interval_ms = 5000

    # Local: needs services.ollama.enable = true (currently false in
    # non_home_manager_config/ollama.nix) plus a small model pulled. The big
    # models loaded there are far too slow for keystroke latency.
    [ai.providers.ollama]
    endpoint = "http://localhost:11434/v1/chat/completions"
    model = "qwen2.5-coder:3b"
    timeout_ms = 2500

    # Cloud alternative. Fast, but note what leaves the machine: cwd, previous
    # command + exit code, `git status` filenames, recent history, and for
    # docker/kubectl/systemctl/git prefixes the gathered output of `docker ps`,
    # `kubectl get pods`, `git branch -a`, `ps -eo` and `systemctl list-units`.
    [ai.providers.groq]
    endpoint = "https://api.groq.com/openai/v1/chat/completions"
    api_key_env = "GROQ_API_KEY"
    model = "llama-3.3-70b-versatile"
    timeout_ms = 3000
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
      # and autopair and install an IPC hook writing into nothing. Upstream
      # guards the same hazard by unsetting the vars when $PPID looks like
      # tmux; comparing against $IRIS_PID is the tighter form of that check
      # (verified: IRIS execs the child shell directly, so $PPID == $IRIS_PID).
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
        # IRIS_CWD keeps IRIS's idea of the directory in sync: it resolves
        # path completions itself, from its own cwd, which never moves because
        # the `cd` happens in the child shell. chpwd covers interactive cds,
        # precmd covers the rest (a script that cds, a subshell popping back).
        # The exit code on IRIS_CMD_STOP feeds the rule-based "retry the last
        # failure" suggestion, which runs with ai.enabled = false. The wrapper
        # accepts a bare IRIS_CMD_STOP too, so both are additive.
        _iris_send_lbuffer() { print -u $IRIS_FD -N -r -- "$LBUFFER" 2>/dev/null }
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
