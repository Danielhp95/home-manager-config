{ pkgs, lib, ... }:

# IPython comes from each project's virtualenv, not this flake, so it is themed
# through ~/.ipython, which every venv's ipython reads. The two style files
# name ANSI slots only, so the terminal's colour0-15 apply and no colour is
# copied from ../palette.nix; what is filled in is which slot plays which role
# (palette.roles.ansi).

let
  roles = (import ../palette.nix).roles.ansi;

  # palette.term's names as pygments and prompt_toolkit spell them: slot 7 is
  # "gray" there, slot 15 "white".
  pygments =
    name:
    {
      white = "ansigray";
      brightWhite = "ansiwhite";
    }
    .${name} or "ansi${lib.toLower name}";
  vars = lib.mapAttrs (_: pygments) roles;
in
{
  home.file = {
    # replaceVars fails the build on a placeholder it was not given, and on a
    # role the file does not use.
    ".ipython/profile_default/ipython_config.py".source = pkgs.replaceVars ./ipython_config.py vars;

    # prompt_toolkit's own widgets (completion popup, ghost text, toolbars) are
    # not pygments tokens, so a startup file restyles them at runtime.
    ".ipython/profile_default/startup/10-ember-ptk-ui.py".source =
      pkgs.replaceVars ./startup-ptk-ui.py
        { inherit (vars) accent; };

    # Ctrl-R as an fzf picker over the history database. Standard library and
    # prompt_toolkit imports only (see its header); fzf and bat come off PATH.
    ".ipython/profile_default/startup/20-fzf-history.py".source = ./startup-fzf-history.py;
  };
}
