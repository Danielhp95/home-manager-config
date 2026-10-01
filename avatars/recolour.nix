# Moves an image's flat, baked-in background colour to another colour at build
# time, leaving the subject alone.
#
# The background is found by flood fill from the image border (so pixels of
# the same colour inside the subject are not touched), feathered by less than a
# pixel, and every pixel is then shifted by mask * (to - from). With
# to == from the shift is zero: the result is the source, pixel for pixel.
{
  lib,
  runCommand,
  imagemagick,
}:
{
  src,
  from, # bare hex: the colour baked into the image
  to, # bare hex: the colour wanted there
  fuzz ? 5, # percent: how far from `from` still counts as background
  name ? "avatar.png",
}:
let
  colour = import ../lib/colour.nix { inherit lib; };
  # Per-channel shift in ImageMagick's 0-1 range.
  shift = lib.zipListsWith (t: f: toString ((t - f) / 255.0)) (colour.channels to) (
    colour.channels from
  );
in
runCommand name { nativeBuildInputs = [ imagemagick ]; } ''
  # White where the background is. The one-pixel border joins every background
  # region that touches an edge, so one fill from 0,0 reaches them all.
  magick ${src} -alpha off \
    -bordercolor '#${from}' -border 1 \
    -alpha set -fuzz ${toString fuzz}% -fill none -draw 'alpha 0,0 floodfill' \
    -shave 1x1 -alpha extract -negate -blur 0x0.6 mask.png

  magick ${src} -alpha off mask.png \
    -fx 'u + v.r * channel(${lib.concatStringsSep ", " shift})' \
    -strip -define png:exclude-chunks=bKGD,date,time \
    $out
''
