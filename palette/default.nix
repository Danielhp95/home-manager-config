# The colours every module imports (`import ./palette`). Which palette they get
# is the one line below; the palettes live beside this file, one each, and
# ./lib.nix documents the shape returned here.
#
# Attributes are bare hex; `hash` is the same set with '#', `ansi` the
# terminal palette (`term` by name), `light` the light-mode set under the same
# names, `meta` the palette's names and non-colour choices, `all` every
# palette by slug.
# (import ./lib.nix).select "ember"
(import ./lib.nix).select "tokyo-night-violet"
