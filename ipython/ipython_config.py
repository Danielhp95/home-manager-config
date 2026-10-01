# The palette by inheritance: every colour is an ANSI slot name (emitted as SGR
# 30-37/90-97), so the terminal's colour0-15 decide and nothing can drift.
# Which slot plays which role differs per palette, so ./default.nix fills the
# at-sign placeholders from palette.nix's roles.ansi. A plain name (ansigreen,
# ansired, ansibrightblack) means that slot in every palette.

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
        Comment.Preproc: "@emphasis@",
        Comment.Special: "bold italic @emphasis@",
        # ── Language structure ──────────────────────────────────────────────
        Keyword: "bold @structure@",
        Keyword.Constant: "@value@",  # True / False / None read as values
        Keyword.Type: "@emphasis@",
        Operator: "",
        Operator.Word: "bold @structure@",  # and / or / not / in / is
        Punctuation: "",
        # ── Names ───────────────────────────────────────────────────────────
        Name: "",
        Name.Builtin: "@metadata@",  # neutral, always-there metadata
        Name.Builtin.Pseudo: "italic @metadata@",  # self, cls
        Name.Class: "bold @definition@",  # the thing you scan for
        Name.Function: "@definition@",
        Name.Function.Magic: "@definition@",
        Name.Decorator: "@emphasis@",
        Name.Exception: "bold @failure@",
        Name.Namespace: "@metadata@",  # module paths in imports
        Name.Constant: "@value@",
        Name.Attribute: "",
        Name.Variable: "",
        Name.Variable.Magic: "@metadata@",  # __name__, __file__
        Name.Tag: "@structure@",
        # ── Literals ────────────────────────────────────────────────────────
        Number: "@value@",  # values injected into the code
        String: "@string@",
        String.Doc: "italic @string@",
        String.Affix: "@structure@",  # the f / r / b prefix is syntax, not text
        String.Escape: "@value@",
        String.Interpol: "@value@",
        String.Regex: "@value@",
        # ── Failure — error only, never decoration ──────────────────────────
        Error: "bold @failure@",
        Generic.Error: "@failure@",
        Generic.Traceback: "@failure@",
        # Diff hues, the same in every palette.
        Generic.Deleted: "ansired",
        Generic.Inserted: "ansigreen",
        Generic.Heading: "bold @accent@",
        Generic.Subheading: "bold @structure@",
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
    Token.OutPrompt: "@accent@",
    Token.OutPromptNum: "bold @accentBright@",
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
