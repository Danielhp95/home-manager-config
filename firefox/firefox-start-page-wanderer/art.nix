# Friedrich's *Wanderer above the Sea of Fog* (1818, public domain), fetched
# from Wikimedia Commons by hash and graded into the palette with a gradient
# map: luminance looked up in a five-stop ramp, from black rock to the
# brightest sky (the palette's extra.artRamp; package.nix checks that its last
# stop stays below the page's fg, so text stays the lightest thing).
# Uncropped: the layout hangs the whole portrait on the right.
{
  fetchurl,
  imagemagick,
  runCommand,
  # Five bare-hex stops, darkest first.
  ramp,
}:

let
  painting = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/b/b9/Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg";
    hash = "sha256-4D5bjBnMmShZJln5iDTlaNPeEak+Axq4CT9cPvEX8h0=";
    # Wikimedia 403s some default agents and asks for an identifiable one; no
    # contact details, as this ships in a public config.
    curlOptsList = [
      "--user-agent"
      "firefox-start-page-wanderer/1.0 (nixpkgs fetchurl)"
    ];
  };
  stop = builtins.elemAt ramp;
in
assert builtins.length ramp == 5;
runCommand "wanderer-graded.jpg"
  {
    nativeBuildInputs = [ imagemagick ];
  }
  ''
    # The five stops, linearly interpolated (-filter triangle) into 256 entries.
    magick -size 1x5 xc:'#${stop 0}' \
      -fill '#${stop 1}' -draw 'point 0,1' \
      -fill '#${stop 2}' -draw 'point 0,2' \
      -fill '#${stop 3}' -draw 'point 0,3' \
      -fill '#${stop 4}' -draw 'point 0,4' \
      -filter triangle -resize 1x256! -set colorspace sRGB lut.png

    # sRGB TrueColor before -clut, or the greyscale image makes the lookup grey.
    magick ${painting} \
      -resize x1800 \
      -colorspace gray \
      -contrast-stretch 1%x0.5% \
      -colorspace sRGB -type TrueColor \
      lut.png -clut \
      -strip -quality 88 \
      $out
  ''
