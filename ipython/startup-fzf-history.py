# Replaces IPython's Ctrl-R reverse-i-search with an fzf picker over the
# history database. Descended from https://stackoverflow.com/questions/48203949
# (the same lineage as the ipython-ctrlr-fzf package on PyPI), rewritten to
# drop its pyfzf dependency.
#
# Installed as startup/20-fzf-history.py by ./default.nix.
#
# HARD CONSTRAINT: this file must import nothing outside the standard library
# and prompt_toolkit. It lives in ~/.ipython/profile_default/startup/, which
# every IPython on this machine loads — including the ones inside project
# virtualenvs — but its imports resolve against whichever venv is active. Any
# third-party import here (pyfzf was the original offender) turns a one-time
# install into a `pip install` in every environment. prompt_toolkit is safe
# because IPython's terminal frontend depends on it.
#
# Nothing here may raise past module scope either: a traceback in a startup
# file is printed at every single IPython launch, in every venv.
import shutil
import subprocess

ipython = get_ipython()  # noqa: F821 — injected into the startup namespace


def is_in_empty_line(buf):
    text = buf.text
    cursor_position = buf.cursor_position
    text = text.split("\n")
    for line in text:
        if len(line) >= cursor_position:
            return not line
        else:
            cursor_position -= len(line) + 1


def fzf_i_search(event):
    seen = set()
    history = [i[2] for i in ipython.history_manager.get_tail(5000, include_latest=True)]
    # newest first, deduped, keeping the first (most recent) occurrence
    entries = [s for s in reversed(history) if s and not (s in seen or seen.add(s))]
    if not entries:
        return

    buf = event.current_buffer

    # bat is optional; fall back to plain cat when it is not on PATH
    if shutil.which("bat"):
        preview = "printf '%s' {} | bat --color=always --style=numbers -l py"
    else:
        preview = "printf '%s' {}"

    # --read0/--print0 let entries contain newlines verbatim: fzf renders
    # multi-line items natively since 0.54, so no separator smuggling is
    # needed. FZF_DEFAULT_OPTS is inherited (that is where the Ember colours
    # come from), but its ctrl-e binding opens the selection in nvim as a
    # filename, which is nonsense for a history line — bind it away.
    argv = [
        "fzf",
        "--read0",
        "--print0",
        "--scheme=history",
        "--no-sort",
        "--multi",
        "--border",
        "--height=80%",
        "--margin=1",
        "--padding=1",
        "--highlight-line",
        "--bind=ctrl-e:ignore",
        "--query",
        buf.text,
        "--preview",
        preview,
    ]

    # repaint the prompt line before fzf takes over the screen
    print("", end="\r", flush=True)
    try:
        proc = subprocess.run(
            argv, input="\0".join(entries), capture_output=True, text=True
        )
    except OSError:
        return
    if proc.returncode != 0:  # cancelled with Esc/Ctrl-C, or fzf errored
        return

    selected = [s for s in proc.stdout.split("\0") if s]
    if not selected:
        return
    # multiple selections are concatenated with a blank line in between
    text = "\n\n".join(selected)

    if not is_in_empty_line(buf):
        buf.insert_line_below()
    buf.insert_text(text)


def _install():
    # Startup files are also loaded by Jupyter kernels, which have no
    # prompt_toolkit application — there is simply no Ctrl-R to rebind there.
    if not getattr(ipython, "pt_app", None):
        return
    if not shutil.which("fzf"):
        return

    from prompt_toolkit.enums import DEFAULT_BUFFER
    from prompt_toolkit.filters import HasFocus, HasSelection
    from prompt_toolkit.keys import Keys

    # prompt_toolkit resolves conflicts last-registered-wins, so this shadows
    # IPython's own Ctrl-R without having to unbind it first.
    ipython.pt_app.key_bindings.add_binding(
        Keys.ControlR, filter=(HasFocus(DEFAULT_BUFFER) & ~HasSelection())
    )(fzf_i_search)


try:
    _install()
except Exception:
    pass

del _install
