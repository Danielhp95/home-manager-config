# THE nvim: danvim's package with the selected palette handed to its Lua as
# `nixCats.extra("palette")` (read by danvim/lua/danvim/palette.lua).
#
# Bound once, as `pkgs.danvim`, in ./overlay.nix; home/default.nix and
# home/firefox/default.nix both use that, so the firenvim host can never run
# a differently themed nvim.
#
# A plain function, called with `import`, never `callPackage`: nixpkgs has a
# package called `palette`, and callPackage would fill an argument of that
# name with it.
{ inputs, system }:
let
  pal = import ../palette;
  nvim = inputs.danvim.packages.${system}.nvim;
in
nvim.override (prev: {
  packageDefinitions = prev.packageDefinitions // {
    ${prev.name} = inputs.danvim.utils.mergeCatDefs prev.packageDefinitions.${prev.name} (_: {
      extra.palette =
        # The 25 slots and `ansi`, all with '#'. Named, not `pal.hash` whole:
        # `term` and the rest of `extra` are not danvim's, and would rebuild
        # the wrapper when a start-page colour changes.
        pal.hash.slots // {
          inherit (pal.hash) ansi;
          # The two extras the tokyonight family's syntax needs.
          inherit (pal.hash.extra) orange cyan;
          meta = {
            inherit (pal.meta) name slug;
            inherit (pal.meta.nvim) family; # the base colourscheme
          };
        };
    });
  };
})
