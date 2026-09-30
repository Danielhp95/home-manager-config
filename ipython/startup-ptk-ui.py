# Ember for the prompt_toolkit chrome around the input line (completion popup,
# ghost text, toolbars): not pygments tokens, so ipython_config.py can't reach
# them, and their defaults are hardcoded greys. PromptSession reads its style
# through a DynamicStyle, so reassigning pt_app.style here (startup files run
# after init_prompt_toolkit_cli) applies on the next repaint. ANSI slots only.


def _apply_ember_ptk_ui() -> None:
    from prompt_toolkit.styles import Style, merge_styles

    ip = get_ipython()  # noqa: F821  (injected into startup-file namespace)

    # None under `ipython kernel`, `--simple-prompt`, and non-tty stdin.
    pt_app = getattr(ip, "pt_app", None)
    if pt_app is None:
        return

    ember_ui = Style(
        [
            # Completion popup on the two darkest slots, the coral accent on
            # the selected row instead of the default reverse-video slab
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
