# Undertale mirror-scene GRUB theme (see theme.txt for the layout).
#
# DeterminationMonoWeb.woff is "Determination Mono Web", the fan recreation of
# Undertale's dialogue font (vendored from
# github.com/SatoruGojo231/determination-mono-font). GRUB can't use TTF/WOFF,
# so grub-mkfont bakes a pf2 bitmap for every pixel size theme.txt names; the
# NixOS GRUB installer loads every *.pf2 in the theme directory.
{
  stdenvNoCC,
  grub2,
}:

stdenvNoCC.mkDerivation {
  pname = "undertale-grub-theme";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [ grub2 ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp theme.txt background.png background-selected.png select_w.png $out/
    for size in $(sed -n 's/.*Determination Mono Web Regular \([0-9]*\).*/\1/p' theme.txt | sort -u); do
      grub-mkfont -s $size -o $out/determination-mono-$size.pf2 DeterminationMonoWeb.woff
    done
    runHook postInstall
  '';
}
