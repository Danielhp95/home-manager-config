# Friedrich's *Wanderer above the Sea of Fog* (1818, public domain), fetched
# from Wikimedia Commons by hash and graded into the Ember palette with a
# gradient map: luminance looked up in a five-stop ramp, from black rock to the
# brightest sky (#c8ab94, kept below the page's fg #d8d0c0 so text stays the
# lightest thing). Uncropped: the layout hangs the whole portrait on the right.
{
  fetchurl,
  imagemagick,
  runCommand,
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
in
runCommand "wanderer-ember.jpg"
  {
    nativeBuildInputs = [ imagemagick ];
  }
  ''
    # The five stops, linearly interpolated (-filter triangle) into 256 entries.
    magick -size 1x5 xc:'#0c0b0a' \
      -fill '#221c19' -draw 'point 0,1' \
      -fill '#4a3b33' -draw 'point 0,2' \
      -fill '#8a7061' -draw 'point 0,3' \
      -fill '#c8ab94' -draw 'point 0,4' \
      -filter triangle -resize 1x256! -set colorspace sRGB ember-lut.png

    # sRGB TrueColor before -clut, or the greyscale image makes the lookup grey.
    magick ${painting} \
      -resize x1800 \
      -colorspace gray \
      -contrast-stretch 1%x0.5% \
      -colorspace sRGB -type TrueColor \
      ember-lut.png -clut \
      -strip -quality 88 \
      $out
  ''
