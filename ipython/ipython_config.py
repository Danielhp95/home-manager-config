# IPython — Ember by inheritance, not by copy.
#
# Unlike every other consumer of ../palette.nix, this file contains NO hex
# values. Every colour below is an ANSI *slot name* (ansired, ansibrightblue,
# …). Pygments and prompt_toolkit pass those straight through as SGR 30-37 /
# 90-97, so the terminal resolves them against its own colour0–15. kitty and
# ghostty already map those 16 slots to Ember, so IPython inherits the theme for
# free — including over SSH, inside tmux, and through any future palette edit,
# with no second copy to drift.
#
# The slots, as kitty/ghostty map them (palette.nix attribute in brackets):
#
#   0/8   ansiblack   / ansibrightblack     [bg      / muted]
#   1/9   ansired     / ansibrightred       [accent  / accentBright]   the coral
#   2/10  ansigreen   / ansibrightgreen     [olive   / oliveBright]
#   3/11  ansiyellow  / ansibrightyellow    [gold    / goldBright]
#   4/12  ansiblue    / ansibrightblue      [steel   / steelBright]
#   5/13  ansimagenta / ansibrightmagenta   [mauve   / mauveBright]
#   6/14  ansicyan    / ansibrightcyan      [sage    / sageBright]
#   7/15  ansigray    / ansiwhite           [fg      / pure white]
#
# Token→slot assignment follows the semantics palette.nix documents for each
# hue: olive = strings, gold = types / needs-attention, steel = neutral
# metadata, mauve = language structure, sage = injected or dynamic values,
# accent = the rationed hero (here: function and class definitions).

from pygments.style import Style
from pygments.token import (
    Comment,
    Error,
    Generic,
    Keyword,
    Name,
    Number,
    Operator,
    Punctuation,
    String,
    Token,
    Whitespace,
)


class EmberAnsi(Style):
    """Pygments style that defers every colour to the terminal's ANSI palette.

    Tokens left undefined inherit from their parent token: prompt_toolkit
    expands ``pygments.name.function.magic`` into a match against
    ``pygments.name``, ``pygments.name.function`` and the full path, so only
    the deviations need spelling out.
    """

    name = "ember-ansi"

    # Empty means "leave it alone" — the terminal's own background and default
    # foreground show through, so a translucent/blurred terminal stays that way.
    background_color = ""
    highlight_color = "ansibrightblack"
    line_number_color = "ansibrightblack"
    line_number_background_color = ""

    styles = {
        Token: "",  # default: terminal foreground
        Whitespace: "ansibrightblack",
        # ── Comments ────────────────────────────────────────────────────────
        Comment: "italic ansibrightblack",
        Comment.Preproc: "ansiyellow",
        Comment.Special: "bold italic ansiyellow",
        # ── Language structure — mauve ──────────────────────────────────────
        Keyword: "bold ansimagenta",
        Keyword.Constant: "ansicyan",  # True / False / None read as values
        Keyword.Type: "ansiyellow",
        Operator: "",
        Operator.Word: "bold ansimagenta",  # and / or / not / in / is
        Punctuation: "",
        # ── Names ───────────────────────────────────────────────────────────
        Name: "",
        Name.Builtin: "ansiblue",  # steel: neutral, always-there metadata
        Name.Builtin.Pseudo: "italic ansiblue",  # self, cls
        Name.Class: "bold ansired",  # accent: the thing you scan for
        Name.Function: "ansired",
        Name.Function.Magic: "ansired",
        Name.Decorator: "ansiyellow",
        Name.Exception: "bold ansibrightred",
        Name.Namespace: "ansiblue",  # module paths in imports
        Name.Constant: "ansicyan",
        Name.Attribute: "",
        Name.Variable: "",
        Name.Variable.Magic: "ansiblue",  # __name__, __file__
        Name.Tag: "ansimagenta",
        # ── Literals ────────────────────────────────────────────────────────
        Number: "ansicyan",  # sage: values injected into the code
        String: "ansigreen",  # olive: strings, per palette.nix
        String.Doc: "italic ansigreen",
        String.Affix: "ansimagenta",  # the f / r / b prefix is syntax, not text
        String.Escape: "ansicyan",
        String.Interpol: "ansicyan",  # sage is literally the interpolation hue
        String.Regex: "ansicyan",
        # ── Failure — error only, never decoration ──────────────────────────
        Error: "bold ansibrightred",
        Generic.Error: "ansibrightred",
        Generic.Traceback: "ansibrightred",
        Generic.Deleted: "ansired",
        Generic.Inserted: "ansigreen",
        Generic.Heading: "bold ansired",
        Generic.Subheading: "bold ansimagenta",
        Generic.Prompt: "ansibrightblack",
        Generic.Emph: "italic",
        Generic.Strong: "bold",
    }


c = get_config()  # noqa: F821  (injected by IPython's config loader)

c.TerminalInteractiveShell.highlighting_style = EmberAnsi

# The In/Out prompts are IPython's own tokens, injected after the style class is
# loaded — they have to be set here rather than in `styles` above, or IPython's
# built-in defaults win the merge.
c.TerminalInteractiveShell.highlighting_style_overrides = {
    Token.Prompt: "ansigreen",
    Token.PromptNum: "bold ansibrightgreen",
    Token.OutPrompt: "ansired",
    Token.OutPromptNum: "bold ansibrightred",
}

# Traceback framing, `??` source display and `%pycat` do not go through
# pygments; they use IPython's own ColorANSI schemes, which already emit bare
# SGR 30-37 codes and therefore already follow the terminal. Only the slot
# *choice* differs between schemes — 'Linux' is the one tuned for a dark
# background.
c.InteractiveShell.colors = "Linux"

# The source snippet *inside* a traceback is the exception: `VerboseTB` renders
# it with pygments' `default` style — the light-background one, full of hardcoded
# hex — through a Terminal256Formatter, so every exception you hit prints a
# little slab of off-palette pastel. `_tb_highlight_style` is a plain class
# attribute rather than a trait, and it is resolved by *name* against pygments'
# registry, which we cannot add to without installing a package. Rebinding the
# name ultratb imported is the small end of the wedge: one lookup, one caller.
#
# `_tb_highlight` (the band behind the failing expression) is deliberately left
# alone — it is already `bg:ansiyellow`, i.e. already the terminal's gold.
try:
    from IPython.core import ultratb

    _pygments_get_style_by_name = ultratb.get_style_by_name

    def _get_style_by_name(name):
        if name == EmberAnsi.name:
            return EmberAnsi
        return _pygments_get_style_by_name(name)

    # Idempotent: config files can be loaded more than once per process, and
    # without the marker each pass would wrap the previous wrapper.
    _get_style_by_name._ember = True
    if not getattr(_pygments_get_style_by_name, "_ember", False):
        ultratb.get_style_by_name = _get_style_by_name
    ultratb.VerboseTB._tb_highlight_style = EmberAnsi.name
except Exception:  # noqa: BLE001 — an IPython upgrade may rename any of this;
    pass  # a stale patch must not be able to break the shell.

# Leave true_color off. It only affects how #rrggbb styles are emitted, and
# turning it on gains nothing here (nothing above is a hex value) while making
# it easy to reintroduce hardcoded colours by accident later.
c.TerminalInteractiveShell.true_color = False
