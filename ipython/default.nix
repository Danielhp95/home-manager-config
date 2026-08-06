{ ... }:

# IPython — the only themed app here that does NOT read ../palette.nix.
#
# IPython is not installed by this flake: it comes from whichever project
# virtualenv is active (uv/poetry/nix-shell), so its version moves independently
# of a `nh os switch`. What is stable is where it looks for configuration —
# $IPYTHONDIR, defaulting to ~/.ipython — so theming lives there and applies to
# every venv's ipython at once, including ones created next year.
#
# Out of the box IPython highlights input with pygments' `default` style: a
# light-background theme of hardcoded hex (#008000 strings, #0000FF names) that
# is *invariant* to the terminal palette, which is why an Ember terminal still
# renders IPython in Jupyter-notebook pastels. ./ipython_config.py replaces it
# with a style expressed purely in ANSI slot names, so the terminal — kitty,
# ghostty, or whatever a future one is — resolves the colours from its own
# colour0–15. Nothing is duplicated from ../palette.nix and nothing can drift;
# editing the palette re-themes IPython with no change here.
#
# See ./ipython_config.py for the slot→palette.nix mapping and the reasoning
# behind each token assignment.

{
  home.file = {
    ".ipython/profile_default/ipython_config.py".source = ./ipython_config.py;

    # The prompt_toolkit widgets (completion popup, ghost text, toolbars) are
    # not pygments tokens and cannot be reached from ipython_config.py; they get
    # restyled at runtime from a startup file. Numbered so ordering stays
    # obvious if a second one ever shows up.
    ".ipython/profile_default/startup/10-ember-ptk-ui.py".source = ./startup-ptk-ui.py;

    # Ctrl-R replaced with an fzf picker over the history database, which beats
    # prompt_toolkit's built-in reverse-i-search. Same reasoning as the theming
    # above: one link, every venv's ipython, because ~/.ipython is per-user.
    #
    # The startup file deliberately imports nothing but the standard library
    # and prompt_toolkit — see its header. It shells out to fzf and bat off
    # PATH (from ../terminal and ../zsh) rather than having store paths baked
    # in, so that ../sony_ai/sai_docker_config.yaml can keep bind-mounting the
    # same file into a container with no /nix/store.
    ".ipython/profile_default/startup/20-fzf-history.py".source = ./startup-fzf-history.py;
  };
}
