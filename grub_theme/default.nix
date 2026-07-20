# Undertale mirror-scene GRUB theme (see theme.txt for the layout).
#
# DeterminationMonoWeb.woff is "Determination Mono Web", the fan recreation of
# Undertale's dialogue font (vendored from
# github.com/SatoruGojo231/determination-mono-font). GRUB can't use TTF/WOFF
# directly, so grub-mkfont bakes it into pf2 bitmaps at the exact pixel sizes
# theme.txt references; the NixOS GRUB installer loadfont's every *.pf2 it
# finds in the theme directory.
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
    cp theme.txt background.png $out/
    for size in 32 48 72; do
      grub-mkfont -s $size -o $out/determination-mono-$size.pf2 DeterminationMonoWeb.woff
    done
    runHook postInstall
  '';
}
