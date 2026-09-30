{
  stdenvNoCC,
  lib,
  librsvg,
  replaceVars,
}:

let
  p = (import ../../palette.nix).hash;

  # Ember.conf and the SVGs name their colors by palette attribute; these are
  # the attributes each file uses.
  themeConf = replaceVars ./Ember.conf {
    inherit (p)
      fg
      fgDim
      muted
      bg
      bgAlt
      bgDeep
      surface
      accent
      accentDim
      ;
  };
  glyphColors = { inherit (p) accent bgDeep; };
  arrow = replaceVars ./arrow.svg glyphColors;
  radio = replaceVars ./radio.svg glyphColors;
in
stdenvNoCC.mkDerivation {
  pname = "fcitx5-ember";
  version = "1.2";

  dontUnpack = true;

  # rsvg-convert, for rasterising the menu glyphs. Keeping the sources as SVG
  # means the shapes stay reviewable in the repo instead of arriving as opaque
  # binaries, and their colors come from palette.nix like the theme's.
  nativeBuildInputs = [ librsvg ];

  installPhase = ''
    runHook preInstall

    # classicui only loads themes/<name>/theme.conf — any other filename
    # (e.g. Ember.conf) is invisible to fcitx5.
    mkdir -pv $out/share/fcitx5/themes/Ember
    cp -v ${themeConf} $out/share/fcitx5/themes/Ember/theme.conf

    # Menu glyphs. The sizes match upstream's default theme so menu metrics
    # line up; classicui blits these as-is, applying no tint of its own, so
    # the colors baked in here are final.
    rsvg-convert -w 6 -h 12 ${arrow} -o $out/share/fcitx5/themes/Ember/arrow.png
    rsvg-convert -w 24 -h 24 ${radio} -o $out/share/fcitx5/themes/Ember/radio.png

    runHook postInstall
  '';

  meta = {
    description = "Fcitx5 Ember theme (warm monochrome with coral accent)";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
