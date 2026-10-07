# Tools for working with Nix itself; the television nix-* channels use the
# first two.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  # command-not-found hints, from the prebuilt nix-index-database index
  # (imported above) rather than a hand-run `nix-index`
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  # `, <cmd>` runs any nixpkgs program without installing it (pkgs.comma on
  # its own would collide with this wrapped one)
  programs.nix-index-database.comma.enable = true;

  home.packages = [
    pkgs.nvd # Nix version diff tool
    pkgs.manix # NixOS/home-manager options search (backs `tv nix-options`)
    # Any binary nixpkgs ever shipped, in a per-shell mount namespace. Not the
    # NixOS module: it replaces /nix/store system-wide (meant for VMs).
    pkgs.omnibin-shell
    pkgs.omnibin
  ];
}
