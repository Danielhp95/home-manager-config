# The interactive shells, and what they share. Home Manager writes
# home.shellAliases and home.sessionVariables into every enabled shell; a
# string both configurations quote is in ./common.nix. What is written twice
# on purpose stays in each shell's own file (functions, in each language).
{ lib, ... }:
{
  imports = [
    ./zsh
    ./nushell.nix
  ];

  # The one option this repository declares: several modules each own a
  # session variable that a palette switch changes, and zsh needs the list.
  options.my.liveSessionVariables = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "LS_COLORS" ];
    description = ''
      Names of home.sessionVariables that every new zsh exports again.
      Session variables are read once per login, and a tmux server keeps the
      environment it started with; restated per shell, a changed value
      reaches a new pane without a new login.
    '';
  };

  config = {
    home.shellAliases = {
      fm = "yazi";
      wow = "git status --untracked-files=no";
      # Generation switcher (the television channel in ../terminal/television.nix).
      ng = "tv nix-generations";
    };

    home.sessionVariables.EDITOR = "nvim";
  };
}
