# Builds only if every palette's GTK theme, cursor and icon theme exist under
# the names its `meta` gives. The schema (./lib.nix) checks that these are
# functions and strings; whether the package still exists in nixpkgs, and still
# ships a theme of that name, only shows when the palette is selected. This
# asks for all of them at once: `nix build .#checks.x86_64-linux.palettes`.
{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix) all;

  dirs =
    palette:
    let
      inherit (palette) meta;
    in
    [
      "${meta.gtk.package pkgs}/share/themes/${meta.gtk.name}"
      "${meta.cursor.package pkgs}/share/icons/${meta.cursor.name}/cursors"
      "${meta.icons.package pkgs}/share/icons/${meta.icons.name}"
    ];
in
pkgs.runCommand "palette-assets" { } ''
  ${lib.concatMapStringsSep "\n" (dir: "test -d ${dir} || { echo missing: ${dir}; exit 1; }") (
    lib.concatMap dirs (lib.attrValues all)
  )}
  touch $out
''
