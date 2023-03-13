final: prev: {
  __dontExport = true; # overrides clutter up actual creations

  # To have all nice tree-sitter grammars
  nvimbundle = prev.neovimBuilder (import ./nvim/neovim-pkg.nix prev);
}
