# Undertale mirror-scene GRUB theme (see theme.txt for the layout).
#
# DeterminationMonoWeb.woff is "Determination Mono Web", the fan recreation of
# Undertale's dialogue font (vendored from
# github.com/SatoruGojo231/determination-mono-font). GRUB can't use TTF/WOFF,
# so grub-mkfont bakes a pf2 bitmap for every pixel size theme.txt names; the
# NixOS GRUB installer loads every *.pf2 in the theme directory.
#
# select_w.png (the SOUL heart, 48x56 pixel art) is upscaled 2x with a point
# filter for the 3840x2400 mode GRUB runs in; GRUB draws pixmaps unscaled.
{
  stdenvNoCC,
  grub2,
  imagemagick,
}:

stdenvNoCC.mkDerivation {
  pname = "undertale-grub-theme";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [
    grub2
    imagemagick
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp theme.txt background.png background-selected.png $out/
    # PNG32: keep the source's 8-bit RGBA; left alone, ImageMagick writes a
    # palette PNG for a two-colour image.
    magick select_w.png -filter point -resize 200% -strip PNG32:$out/select_w.png
    for size in $(sed -n 's/.*Determination Mono Web Regular \([0-9]*\).*/\1/p' theme.txt | sort -u); do
      grub-mkfont -s $size -o $out/determination-mono-$size.pf2 DeterminationMonoWeb.woff
    done
    runHook postInstall
  '';
}
