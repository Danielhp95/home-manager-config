# Ember by inheritance: every colour is an ANSI slot name (emitted as SGR
# 30-37/90-97), so the terminal's colour0-15 decide and nothing can drift.
# Slots: red accent (coral), green olive, yellow gold, blue steel, magenta
# mauve, cyan sage, brightblack muted. Roles: olive strings, gold types,
# steel metadata, mauve structure, sage injected values, coral definitions.

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

    # Empty: the terminal's own (translucent) background and foreground show
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

# The In/Out prompt tokens are IPython's own, merged in after the style class:
# set them here, or IPython's defaults win.
c.TerminalInteractiveShell.highlighting_style_overrides = {
    Token.Prompt: "ansigreen",
    Token.PromptNum: "bold ansibrightgreen",
    Token.OutPrompt: "ansired",
    Token.OutPromptNum: "bold ansibrightred",
}

# Traceback framing, `??` and %pycat use IPython's ColorANSI schemes (bare SGR
# 30-37, so already the terminal's); 'Linux' is the dark-background one.
c.InteractiveShell.colors = "Linux"

# Except the source snippet inside a traceback: VerboseTB renders it with the
# pygments style named by the plain class attribute `_tb_highlight_style`
# ('default', light-background hex), resolved by name in a registry we can't
# extend without a package, so rebind the name ultratb imported. The band
# behind the failing expression (`_tb_highlight`) is already bg:ansiyellow.
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

# Leave true_color off: it only affects #rrggbb styles (none here), and on it
# would make hardcoded colours easy to reintroduce.
c.TerminalInteractiveShell.true_color = False
