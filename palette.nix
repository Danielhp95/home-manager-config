# The colours every module imports. Which palette they get is the one line
# below; the palettes live in ./palettes, one file each, and
# ./palettes/default.nix documents the shape returned here.
#
# Attributes are bare hex; `hash` is the same set with '#', `ansi` the
# terminal palette (`term` by name), `light` the light-mode set under the same
# names, `meta` the palette's names and non-colour choices, `all` every
# palette by slug.
(import ./palettes).select "ember"
