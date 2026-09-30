{ ... }:

# IPython comes from each project's virtualenv, not this flake, so it is themed
# through ~/.ipython, which every venv's ipython reads. ipython_config.py uses
# ANSI slot names only, so the terminal's Ember colour0-15 apply and nothing is
# copied from ../palette.nix.

{
  home.file = {
    ".ipython/profile_default/ipython_config.py".source = ./ipython_config.py;

    # prompt_toolkit's own widgets (completion popup, ghost text, toolbars) are
    # not pygments tokens, so a startup file restyles them at runtime.
    ".ipython/profile_default/startup/10-ember-ptk-ui.py".source = ./startup-ptk-ui.py;

    # Ctrl-R as an fzf picker over the history database. Standard library and
    # prompt_toolkit imports only (see its header); fzf and bat come off PATH.
    ".ipython/profile_default/startup/20-fzf-history.py".source = ./startup-fzf-history.py;
  };
}
