args@{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    gcc gnumake  # Required for telescope-fzf-native. Ideally we will find away of defining these elsewhere

    (neovimBuilder (import ./neovim-pkg.nix args))
  ];
}
