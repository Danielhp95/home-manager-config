# Undertale mirror-scene GRUB theme (layout in theme.txt). The font is the fan
# "Determination Mono Web" (github.com/SatoruGojo231/determination-mono-font),
# baked by grub-mkfont into a pf2 per pixel size theme.txt names. The pixel
# art (backgrounds, 48x56 SOUL heart) is upscaled 2x with a point filter for
# the native 3840x2400 mode: GRUB draws pixmaps unscaled and smooths the
# backgrounds when it stretches them.
#
# Build it alone with `nix build .#grub-theme`.
{
  lib,
  stdenvNoCC,
  grub2,
  imagemagick,
}:

stdenvNoCC.mkDerivation {
  pname = "undertale-grub-theme";
  version = "1.0";

  # Everything here but this file: a comment edit above then rebuilds nothing,
  # and so does not re-run the bootloader's install hooks on the next switch.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.difference ./. ./package.nix;
  };

  nativeBuildInputs = [
    grub2
    imagemagick
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp theme.txt $out/
    # PNG32: keep the sources' 8-bit RGBA; left alone, ImageMagick writes a
    # palette PNG for a two-colour image.
    for img in background.png background-selected.png select_w.png; do
      magick $img -filter point -resize 200% -strip PNG32:$out/$img
    done
    for size in $(sed -n 's/.*Determination Mono Web Regular \([0-9]*\).*/\1/p' theme.txt | sort -u); do
      grub-mkfont -s $size -o $out/determination-mono-$size.pf2 DeterminationMonoWeb.woff
    done
    runHook postInstall
  '';
}
