# The editor, and command-line utilities with nothing to configure here.
{ pkgs, ... }:
{
  home.packages = [
    pkgs.danvim # nvim, with the selected palette (pkgs/danvim.nix)
    pkgs.ripgrep # better grep; the television text channel runs it
    pkgs.fd # find alternative; television's file channels run it
    pkgs.dust # du alternative
    pkgs.duf # like du, but for free space
    pkgs.unzip
    pkgs.zip
    pkgs.wget
    pkgs.python3
    pkgs.translate-shell
  ];
}
