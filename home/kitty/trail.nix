# kitty's stock cursor-trail-blaze with its two colours taken from the palette.
# The stock pipeline has no `var` overrides, so this file is that pipeline plus
# two. The shader works in linear light; theme.colour does the conversion.
#
# Returns a store DIRECTORY holding cursor-trail.pipeline. `custom_shaders`
# takes the absolute path, so the option value changes exactly when a colour
# does, and kitty recompiles on the reload that follows (it compares that
# option, and caches pipelines by name).
{
  lib,
  writeTextDir,
  theme,
}:
{
  # Each: { slot = "<palette attribute>"; hex = "<bare hex>"; }
  fill, # TRAIL_COLOR: the body of the trail
  rim, # TRAIL_COLOR_ACCENT: the thin band along its edge
  # Comment lines only; the default says what the file is.
  header ? [ "kitty's cursor-trail-blaze in the palette's colours (linear RGB). Generated." ],
  label ? c: "${c.slot} #${c.hex}",
}:
let
  inherit (theme) colour;
  float4 = c: "float4(${colour.linear3 c.hex}, 1.0)";
in
writeTextDir "cursor-trail.pipeline" ''
  ${lib.concatMapStringsSep "\n" (line: "# ${line}") header}
  startgroup
      animation_start cursor-trail-move
      animation_stop cursor-trail-stop
      # ${label fill}
      var float4 TRAIL_COLOR = ${float4 fill}
      # ${label rim}
      var float4 TRAIL_COLOR_ACCENT = ${float4 rim}
      shaders cursor-trail-blaze
  endgroup
''
