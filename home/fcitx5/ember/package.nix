{
  stdenvNoCC,
  lib,
  librsvg,
  replaceVars,
}:

let
  p = (import ../../../palette).hash;

  # The palette attributes each file uses as placeholders.
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

  # rsvg-convert rasterises the menu glyphs, kept as reviewable SVG sources.
  nativeBuildInputs = [ librsvg ];

  installPhase = ''
    runHook preInstall

    # classicui only loads themes/<name>/theme.conf — any other filename
    # (e.g. Ember.conf) is invisible to fcitx5.
    mkdir -pv $out/share/fcitx5/themes/Ember
    cp -v ${themeConf} $out/share/fcitx5/themes/Ember/theme.conf

    # Sizes match upstream's default theme; classicui applies no tint, so the
    # colors baked in are final.
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
