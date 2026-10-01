# Nearest xterm-256 colour to a hex value, in plain Nix.
#
# For programs that quantise to the fixed 256-colour table (chroma's
# terminal256 formatter, used by glamour/gh): give them an exact table entry
# and they emit that index unchanged. Only 16-255 are candidates: the terminal
# re-themes 0-15, so those are not fixed colours.
let
  inherit (builtins)
    elemAt
    filter
    foldl'
    genList
    head
    substring
    tail
    ;

  # "6e" -> 110. TOML reads hex integers; Nix has no parser of its own.
  byte = s: (builtins.fromTOML "v = 0x${s}").v;
  rgb = hex: {
    r = byte (substring 0 2 hex);
    g = byte (substring 2 2 hex);
    b = byte (substring 4 2 hex);
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
in
{
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
}
