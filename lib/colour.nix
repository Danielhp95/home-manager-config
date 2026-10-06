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

  # ── The xterm-256 table ──────────────────────────────────────────────────
  # For programs that quantise to the fixed 256-colour table (chroma's
  # terminal256 formatter, used by glamour/gh): give them an exact table entry
  # and they emit that index unchanged. Only 16-255 are candidates: the
  # terminal re-themes 0-15, so those are not fixed colours.
  inherit (builtins)
    elemAt
    filter
    foldl'
    genList
    head
    substring
    tail
    ;
  rgb =
    hex:
    let
      c = channels hex;
    in
    {
      r = elemAt c 0;
      g = elemAt c 1;
      b = elemAt c 2;
    };

  digits = "0123456789abcdef";
  toHexByte = n: substring (n / 16) 1 digits + substring (n - (n / 16) * 16) 1 digits;
  toHex = c: toHexByte c.r + toHexByte c.g + toHexByte c.b;

  # 16-231: the 6x6x6 cube. 232-255: the grey ramp.
  levels = [
    0
    95
    135
    175
    215
    255
  ];
  cube = genList (
    i:
    let
      r = i / 36;
      g = (i - r * 36) / 6;
      b = i - r * 36 - g * 6;
    in
    {
      index = 16 + i;
      r = elemAt levels r;
      g = elemAt levels g;
      b = elemAt levels b;
    }
  ) 216;
  greys = genList (
    i:
    let
      v = 8 + 10 * i;
    in
    {
      index = 232 + i;
      r = v;
      g = v;
      b = v;
    }
  ) 24;

  table = cube ++ greys;

  # "Redmean" squared distance (compuphase.com/cmetric.htm): RGB weighted
  # towards how the eye sees it, in integers only.
  distance =
    a: b:
    let
      rmean = (a.r + b.r) / 2;
      dr = a.r - b.r;
      dg = a.g - b.g;
      db = a.b - b.b;
    in
    ((512 + rmean) * dr * dr) / 256 + 4 * dg * dg + ((767 - rmean) * db * db) / 256;

  # Rec. 709 luma on the encoded values, x10000: enough to order two greys.
  luma = c: 2126 * c.r + 7152 * c.g + 722 * c.b;

  nearestEntry =
    candidates: hex:
    let
      want = rgb hex;
      # Strict <, so the lowest index wins a tie.
      pick = best: c: if distance want c < distance want best then c else best;
    in
    foldl' pick (head candidates) (tail candidates);

  entry = c: {
    inherit (c) index;
    hex = toHex c;
  };

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

  # The xterm-256 entry nearest a colour:
  # nearest "6e6a66" -> { index = 242; hex = "6c6c6c"; }
  nearest = hex: entry (nearestEntry table hex);

  # The same, among entries at least as light as the colour: for dim text on a
  # dark ground, where the nearest entry may be a darker one that no longer
  # reads.
  nearestNoDarker =
    hex:
    let
      want = rgb hex;
      lighter = filter (c: luma c >= luma want) table;
    in
    entry (nearestEntry (if lighter == [ ] then table else lighter) hex);

  # "e08060" -> "0.745, 0.216, 0.117": the three linear-light floats a shader takes.
  linear3 = hex: lib.concatMapStringsSep ", " (n: fixed3 (linearChannel n)) (channels hex);
}
