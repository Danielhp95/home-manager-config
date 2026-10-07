# Tools for working with Nix itself; the television nix-* channels use the
# first two.
{ pkgs, ... }:
{
  home.packages = [
    pkgs.nvd # Nix version diff tool
    pkgs.manix # NixOS/home-manager options search (backs `tv nix-options`)
    # Any binary nixpkgs ever shipped, in a per-shell mount namespace. Not the
    # NixOS module: it replaces /nix/store system-wide (meant for VMs).
    pkgs.omnibin-shell
    pkgs.omnibin
  ];
}
