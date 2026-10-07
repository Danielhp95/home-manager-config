# The interactive shells, and what they share. Home Manager writes
# home.shellAliases and home.sessionVariables into every enabled shell; a
# string both configurations quote is in ./common.nix. What is written twice
# on purpose stays in each shell's own file (functions, in each language).
_: {
  imports = [
    ./zsh
    ./nushell.nix
  ];

  home.shellAliases = {
    fm = "yazi";
    wow = "git status --untracked-files=no";
    # Generation switcher (the television channel in ../terminal/television.nix).
    ng = "tv nix-generations";
  };

  home.sessionVariables.EDITOR = "nvim";
}
