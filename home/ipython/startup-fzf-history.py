# Replaces IPython's Ctrl-R reverse-i-search with an fzf picker over the
# history database (after https://stackoverflow.com/questions/48203949,
# minus its pyfzf dependency).
#
# Standard library and prompt_toolkit imports only: every venv's IPython
# loads this file, and any other import would need installing in each venv.
# Nothing may raise past module scope either, or every launch prints it.
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

    # bat is optional; without it the preview is the plain text
    if shutil.which("bat"):
        preview = "printf '%s' {} | bat --color=always --style=numbers -l py"
    else:
        preview = "printf '%s' {}"

    # --read0/--print0 keep multi-line entries intact (fzf >= 0.54 renders
    # them). FZF_DEFAULT_OPTS brings the Ember colours, but its ctrl-e opens
    # the selection in nvim as a filename, so bind that away.
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
    # Jupyter kernels load startup files too, but have no prompt_toolkit app
    if not getattr(ipython, "pt_app", None):
        return
    if not shutil.which("fzf"):
        return

    from prompt_toolkit.enums import DEFAULT_BUFFER
    from prompt_toolkit.filters import HasFocus, HasSelection
    from prompt_toolkit.keys import Keys

    # Last-registered wins, so this shadows IPython's own Ctrl-R
    ipython.pt_app.key_bindings.add_binding(
        Keys.ControlR, filter=(HasFocus(DEFAULT_BUFFER) & ~HasSelection())
    )(fzf_i_search)


try:
    _install()
except Exception:
    pass

del _install
