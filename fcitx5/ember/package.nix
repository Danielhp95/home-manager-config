{
  stdenvNoCC,
  lib,
  librsvg,
}:

stdenvNoCC.mkDerivation {
  pname = "fcitx5-ember";
  version = "1.2";

  src = ./. ; # Local ember theme source dir

  # rsvg-convert, for rasterising the menu glyphs. Keeping the sources as SVG
  # means the shapes and their palette colors stay reviewable in the repo
  # instead of arriving as opaque binaries.
  nativeBuildInputs = [ librsvg ];

  installPhase = ''
    runHook preInstall

    # classicui only loads themes/<name>/theme.conf — any other filename
    # (e.g. Ember.conf) is invisible to fcitx5.
    mkdir -pv $out/share/fcitx5/themes/Ember
    cp -v Ember.conf $out/share/fcitx5/themes/Ember/theme.conf

    # Menu glyphs. The sizes match upstream's default theme so menu metrics
    # line up; classicui blits these as-is, applying no tint of its own, so
    # the colors baked in here are final.
    rsvg-convert -w 6 -h 12 arrow.svg -o $out/share/fcitx5/themes/Ember/arrow.png
    rsvg-convert -w 24 -h 24 radio.svg -o $out/share/fcitx5/themes/Ember/radio.png

    runHook postInstall
  '';

  meta = {
    description = "Fcitx5 Ember theme (warm monochrome with coral accent)";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
