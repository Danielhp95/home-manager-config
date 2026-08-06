# Ember for the prompt_toolkit chrome around the input line.
#
# ../ipython_config.py themes everything IPython renders through pygments (the
# code you type, the prompts). It cannot reach the widgets prompt_toolkit draws
# itself — the completion popup, the autosuggest ghost text, the search and
# validation toolbars. Those live under prompt_toolkit's own style classes
# rather than `pygments.*` tokens, and prompt_toolkit's defaults for them are
# hardcoded greys (`bg:#bbbbbb #000000` for the completion menu), which is the
# one part of the UI that stays stubbornly off-palette on an Ember terminal.
#
# `PromptSession` reads its style through `DynamicStyle(lambda: self.style)`, so
# reassigning `pt_app.style` after the shell is up takes effect on the next
# repaint — no subclassing, no re-init. Startup files run after
# `init_prompt_toolkit_cli`, so `pt_app` already exists by the time we get here.
#
# ANSI slot names only, for the same reason as ipython_config.py: the terminal
# owns the palette.


def _apply_ember_ptk_ui() -> None:
    from prompt_toolkit.styles import Style, merge_styles

    ip = get_ipython()  # noqa: F821  (injected into startup-file namespace)

    # None under `ipython kernel`, `--simple-prompt`, and non-tty stdin.
    pt_app = getattr(ip, "pt_app", None)
    if pt_app is None:
        return

    ember_ui = Style(
        [
            # Completion popup: Ember's `surface` row over `bgAlt`, approximated
            # by the two darkest ANSI slots, with the coral accent on the
            # selected row rather than the default reverse-video white slab.
            ("completion-menu", "bg:ansiblack ansigray"),
            ("completion-menu.completion", "bg:ansiblack ansigray"),
            ("completion-menu.completion.current", "bg:ansired ansiblack"),
            ("completion-menu.meta.completion", "bg:ansiblack ansibrightblack"),
            ("completion-menu.meta.completion.current", "bg:ansired ansiblack"),
            ("completion-menu.multi-column-meta", "bg:ansiblack ansibrightblack"),
            # Fuzzy-match emphasis inside a completion.
            ("completion-menu.completion fuzzymatch.outside", "ansibrightblack"),
            ("completion-menu.completion fuzzymatch.inside", "bold ansigray"),
            (
                "completion-menu.completion fuzzymatch.inside.character",
                "underline",
            ),
            ("completion-menu.completion.current fuzzymatch.outside", "ansiblack"),
            ("completion-menu.completion.current fuzzymatch.inside", "bold"),
            # Single-line completion bar (`display_completions = 'column'`).
            ("completion-toolbar", "bg:ansiblack ansigray"),
            ("completion-toolbar.arrow", "bold bg:ansiblack ansired"),
            ("completion-toolbar.completion", "bg:ansiblack ansigray"),
            ("completion-toolbar.completion.current", "bg:ansired ansiblack"),
            # History ghost text — must read as not-yet-real, so: muted.
            ("auto-suggestion", "ansibrightblack"),
            # Search and errors.
            ("search", "bg:ansiyellow ansiblack"),
            ("search.current", "bg:ansibrightyellow ansiblack"),
            ("search-toolbar", "bold ansigray"),
            ("search-toolbar.text", "nobold ansigray"),
            ("validation-toolbar", "bg:ansired ansiblack"),
            ("scrollbar.background", "bg:ansiblack"),
            ("scrollbar.button", "bg:ansibrightblack"),
        ]
    )

    # Ours goes last: in prompt_toolkit's merge, later rules win.
    pt_app.style = merge_styles([pt_app.style, ember_ui])


_apply_ember_ptk_ui()

# Startup files execute in the user namespace — leave it as we found it.
del _apply_ember_ptk_ui
