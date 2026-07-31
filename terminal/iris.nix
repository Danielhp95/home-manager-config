{ pkgs, lib, ... }:
let
  p = (import ../palette.nix).hash;

  # IRIS has no theming, no width setting and hardcodes Tab — the README's
  # "2 basic styles" is the whole story. All three are one-file constants, so
  # they get patched here, in the same spirit as the fzf override in
  # ./default.nix. Every replacement is --replace-fail: if upstream moves a
  # line, the build breaks loudly instead of silently reverting to purple.
  iris = pkgs.iris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ### Theme: Ember, straight from ../palette.nix ##########################
      # Upstream ships the Aura palette (purple #a277ff / mint #61ffca) as
      # lipgloss hex literals in integration/overlay.go. Border goes first and
      # qualified by its field name: it shares #a277ff with the accent roles,
      # and it's the one that should stay quiet rather than become gold.
      substituteInPlace integration/overlay.go \
        --replace-fail 'Border:     lipgloss.Color("#a277ff")' 'Border:     lipgloss.Color("${p.border}")'

      # Remaining #a277ff: scroll counter, alias/system pills, footer keys.
      substituteInPlace integration/overlay.go \
        --replace-fail '"#a277ff"' '"${p.gold}"' \
        --replace-fail '"#61ffca"' '"${p.accent}"' \
        --replace-fail '"#6d6a7f"' '"${p.muted}"' \
        --replace-fail '"#edecee"' '"${p.fg}"' \
        --replace-fail '"#ffffff"' '"${p.fg}"' \
        --replace-fail '"#9692a8"' '"${p.fgDim}"' \
        --replace-fail '"#3d375e"' '"${p.surface}"' \
        --replace-fail '"#4B4A4C"' '"${p.muted}"' \
        --replace-fail '"#2a2342"' '"${p.bgAlt}"' \
        --replace-fail '"#1a2d36"' '"${p.bgAlt}"' \
        --replace-fail '"#1e1d28"' '"${p.bgAlt}"' \
        --replace-fail '"#110f18"' '"${p.bg}"'

      ### Width: fill the terminal instead of a fixed 76 columns #############
      # boxWidth is `const boxWidth = 76`, and the command column derives from
      # it as inner - marker - icon - padGap - descW, which left roughly 41
      # characters before truncation. The const is only read in this one
      # function, so a same-name local shadows it everywhere it matters (the
      # RHS still sees the const: a short var decl's scope starts after it).
      # 76 stays the floor, 200 caps it on ultrawide terminals. Narrower
      # terminals behave exactly as before — targetCol is already clamped at 0
      # and autowrap is off, so an oversized box clips rather than corrupts.
      substituteInPlace integration/overlay.go \
        --replace-fail 'if targetCol+boxWidth > width {' 'boxWidth := min(max(width-2, boxWidth), 200); if targetCol+boxWidth > width {'

      # Let the description column grow with the box too, instead of a fixed
      # 24, while still leaving the bulk of the extra room to the command.
      substituteInPlace integration/overlay.go \
        --replace-fail 'descW := 24' 'descW := max(24, inner/4)'

      ### Tab: hand it back to the shell when no menu is open #################
      # Upstream's Tab branch sets intercepted = true and returns without ever
      # writing to the pty, so fzf-tab and the Tab-Tab television binding are
      # unreachable inside a session. Forwarding Tab whenever IRIS has no menu
      # open restores both; with the menu open Tab still accepts the
      # suggestion. Deliberately does not set shouldOverlayDraw: IRIS must not
      # redraw over fzf-tab's own output.
      substituteInPlace root/wrapper.go \
        --replace-fail 'logger.Debugf("Intercepted Tab key, visible=%v", overlay.IsVisible())' 'logger.Debugf("Intercepted Tab key, visible=%v", overlay.IsVisible()); if !overlay.IsVisible() { _, _ = ptmx.Write([]byte{b}); continue }'

      ### Ctrl-J / Ctrl-K: move down/up the list, as in nvim, tv and fzf #######
      # Menu navigation is Up/Down only, and both are matched deep inside the
      # escape-sequence branch of the input pump, so there is no single key
      # constant to repoint. Instead this rewrites the keystroke on the way in:
      # while the menu is open, a lone Ctrl-K (0x0b) becomes ESC [ A and a lone
      # Ctrl-J (0x0a) becomes ESC [ B, and every existing arrow path — cursor
      # move, history-mode line replacement, ghost text, redraw — then runs
      # unchanged. Bytes are spelled in hex because '[' cannot appear inside
      # this single-quoted shell argument.
      #
      # Terminals send 0x0a for Ctrl-J and 0x0d for Enter, and IRIS puts stdin
      # in raw mode (no ICRNL), so the two stay distinct here even though the
      # Enter branch below accepts either.
      #
      # Guards, both load-bearing. `overlay.IsVisible()` keeps the keys as zsh's
      # own when there is no list to move through: Ctrl-J still accepts the line
      # and Ctrl-K still kills to the end of it. `n == 1` limits the rewrite to a
      # solitary keystroke, so newlines inside a pasted block are never turned
      # into Down — the bracketed-paste markers arrive in the same read as the
      # body, which means inBracketedPaste is not yet set when this runs.
      substituteInPlace root/wrapper.go \
        --replace-fail 'logger.Debugf("Stdin raw input: bytes=%q, hex=%x", inputSlice[:n], inputSlice[:n])' 'logger.Debugf("Stdin raw input: bytes=%q, hex=%x", inputSlice[:n], inputSlice[:n]); if overlay.IsVisible() && n == 1 && !inBracketedPaste { if inputSlice[0] == 0x0b { inputSlice, n = []byte{0x1b, 0x5b, 0x41}, 3 } else if inputSlice[0] == 0x0a { inputSlice, n = []byte{0x1b, 0x5b, 0x42}, 3 } }'
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
# Upstream intercepts Tab unconditionally — its branch in root/wrapper.go sets
# intercepted=true and returns without ever writing to the pty — which makes
# fzf-tab and the Tab-Tab television binding unreachable inside a session.
# The patch below forwards Tab whenever IRIS has no menu open, so both work
# again. Note the remaining overlap: while the suggestion menu *is* up (which
# is most of the time you're mid-word), Tab accepts IRIS's selection. Toggle
# the menu off to hand the key back. To make Tab always defer to zsh instead,
# drop the `if !overlay.IsVisible()` guard from that patch so it forwards
# unconditionally — you'd then accept suggestions only with Right/ghost-text.
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

  # Managed declaratively, so never run `iris config init` / `iris setup`:
  # setup prepends `eval "$(iris init zsh)"` to .zshrc, which is a read-only
  # store symlink here. Runtime state (last-used mode) goes to
  # $XDG_DATA_HOME/iris/state.toml, not this file, so read-only is safe.
  # IRIS stats this path every second and hot-reloads, so a rebuild applies
  # to running sessions without restarting them.
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

    [ui]
    style = "modern"
    ghost-text = true
    hidden-files = false
    max-suggestions = 100
    max-height = 12
    nerd-fonts = true

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
    # Only these two are configurable; Tab / Enter / arrows / Ctrl-A,E,L,U,W,C
    # are hardcoded in the input pump — as is the Ctrl-J/Ctrl-K navigation
    # patched in above, which is why it lives there and not here.
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
        # line-pre-redraw feeds zle's authoritative buffer to IRIS, which
        # otherwise only has its own naive keystroke mirror — this is what
        # keeps the overlay honest when a widget rewrites the line.
        _iris_send_lbuffer() { print -u $IRIS_FD -N -r -- "$LBUFFER" 2>/dev/null }
        _iris_precmd()       { print -u $IRIS_FD -N -r -- "IRIS_CMD_STOP" 2>/dev/null }
        _iris_preexec()      { print -u $IRIS_FD -N -r -- "IRIS_CMD_START" 2>/dev/null }

        autoload -Uz add-zle-hook-widget add-zsh-hook
        add-zle-hook-widget line-pre-redraw _iris_send_lbuffer
        add-zsh-hook precmd _iris_precmd
        add-zsh-hook preexec _iris_preexec
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
