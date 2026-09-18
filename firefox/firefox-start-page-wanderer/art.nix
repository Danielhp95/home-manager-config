# Caspar David Friedrich, *Wanderer above the Sea of Fog* (1818), re-lit in the
# Ember palette for the start page.
#
# The painting is public domain (the painter died in 1840) and is fetched from
# Wikimedia Commons at its full 2327x2980, pinned by hash. Nothing binary
# enters this repo.
#
# The grade is a gradient map, not a filter stack: the image is flattened to
# luminance, stretched, and every grey level is then looked up in a five-stop
# ramp. That is what keeps it in the same family as ../../palette.nix instead
# of "sepia-toned photo". The stops are the ones approved from the mockups:
#
#   #0c0b0a  black rock        (a touch deeper than palette bgDeep)
#   #221c19  shadowed slopes
#   #4a3b33  mid ground
#   #8a7061  lit fog
#   #c8ab94  the brightest sky (deliberately short of white, so the page's
#            own text at fg #d8d0c0 still reads as the lightest thing on it)
#
# Kept portrait and uncropped: the "gallery wall" layout hangs the whole canvas
# on the right edge of the page and fades it into the dashboard column, so
# cropping it to a landscape ratio here would undo the composition.
{
  fetchurl,
  imagemagick,
  runCommand,
}:

let
  painting = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/b/b9/Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg";
    hash = "sha256-4D5bjBnMmShZJln5iDTlaNPeEak+Axq4CT9cPvEX8h0=";
    # upload.wikimedia.org answers 403 to some default agents; Wikimedia's
    # user-agent policy asks for something identifiable. No contact details
    # here on purpose — this string ships in a public config.
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
    # The five stops as a 1x5 image, resized to a 256-entry ramp. `-filter
    # triangle` makes that a linear interpolation between them.
    magick -size 1x5 xc:'#0c0b0a' \
      -fill '#221c19' -draw 'point 0,1' \
      -fill '#4a3b33' -draw 'point 0,2' \
      -fill '#8a7061' -draw 'point 0,3' \
      -fill '#c8ab94' -draw 'point 0,4' \
      -filter triangle -resize 1x256! -set colorspace sRGB ember-lut.png

    # -colorspace sRGB -type TrueColor before -clut: without it the greyscale
    # image stays in a grey colorspace and the lookup comes back grey, which
    # is exactly the bug the first mockup shipped with.
    magick ${painting} \
      -resize x1800 \
      -colorspace gray \
      -contrast-stretch 1%x0.5% \
      -colorspace sRGB -type TrueColor \
      ember-lut.png -clut \
      -strip -quality 88 \
      $out
  ''
