# Palette-independent colour arithmetic and formatting, pure Nix (no pkgs, no
# build step). Every function takes bare 6-digit hex, the palette's native
# form; a consumer never spells a colour format by hand.
{ lib }:
let
  channels =
    hex:
    map (i: lib.fromHexString (builtins.substring i 2 hex)) [
      0
      2
      4
    ];
  join = sep: hex: lib.concatMapStringsSep sep toString (channels hex);

  # Nix has no pow(), but x^2.4 = x^2 * (x^2)^(1/5), and a fifth root is a few
  # Newton steps: y <- (4y + a/y^4) / 5. From y = 1 it converges monotonically
  # for every a in (0, 1]; 40 steps is far past double precision.
  root5 =
    a:
    if a <= 0.0 then
      0.0
    else
      builtins.foldl' (y: _: (4.0 * y + a / (y * y * y * y)) / 5.0) 1.0 (lib.range 1 40);

  # IEC 61966-2-1 sRGB transfer function, one 8-bit channel -> linear [0, 1].
  linearChannel =
    n:
    let
      c = n / 255.0;
      t = (c + 0.055) / 1.055;
    in
    if c <= 0.04045 then c / 12.92 else t * t * root5 (t * t);

  # Round half up to three decimals: 0.04 -> "0.040", 1.0 -> "1.000".
  fixed3 =
    x:
    let
      n = builtins.floor (x * 1000 + 0.5);
    in
    "${toString (n / 1000)}.${lib.fixedWidthString 3 "0" (toString (lib.mod n 1000))}";

  # WCAG relative luminance, 0 (black) to 1 (white).
  luminance =
    hex:
    let
      c = map linearChannel (channels hex);
      at = builtins.elemAt c;
    in
    0.2126 * at 0 + 0.7152 * at 1 + 0.0722 * at 2;

  rgbCommas = join ", "; # "e9873a" -> "233, 135, 58" (CSS rgba(r, g, b, a))

  # bgDeep -> bg-deep; digits and punctuation pass through.
  toKebab =
    name:
    lib.concatMapStrings (
      char: if char == lib.toUpper char && char != lib.toLower char then "-${lib.toLower char}" else char
    ) (lib.stringToCharacters name);
in
{
  inherit
    channels
    linearChannel
    fixed3
    luminance
    rgbCommas
    toKebab
    ;

  hash = hex: "#${hex}"; # "bb9af7" -> "#bb9af7"
  argb = aa: hex: "#${aa}${hex}"; # "#AARRGGBB" (mpv)
  rgba = hex: a: "rgba(${rgbCommas hex}, ${a})"; # CSS, alpha as a decimal string

  rgbSemicolons = join ";"; # "e08060" -> "224;128;96"   (SGR 38;2;…)
  rgbSpaces = join " "; # "d8c6b2" -> "216 198 178"  (CSS rgb(r g b / a))

  # WCAG contrast ratio of two colours, 1 (none) to 21 (black on white).
  contrast =
    a: b:
    let
      la = luminance a;
      lb = luminance b;
    in
    (lib.max la lb + 0.05) / (lib.min la lb + 0.05);

  # An attrset of colours as CSS custom properties, one per line:
  # cssVars "ember" { bgDeep = "#16161e"; } -> "  --ember-bg-deep: #16161e;\n".
  cssVars =
    prefix: colours:
    lib.concatStrings (
      lib.mapAttrsToList (name: value: "  --${prefix}-${toKebab name}: ${value};\n") colours
    );

  # "e08060" -> "0.745, 0.216, 0.117": the three linear-light floats a shader takes.
  linear3 = hex: lib.concatMapStringsSep ", " (n: fixed3 (linearChannel n)) (channels hex);
}
