{
  stdenvNoCC,
  lib,
}:

stdenvNoCC.mkDerivation {
  pname = "fcitx5-ember";
  version = "0-unstable-2024-04-15";

  src = ./. ; # Local ember theme source dir

  installPhase = ''
    runHook preInstall

    # classicui only loads themes/<name>/theme.conf — any other filename
    # (e.g. Ember.conf) is invisible to fcitx5.
    mkdir -pv $out/share/fcitx5/themes/Ember
    cp -v Ember.conf $out/share/fcitx5/themes/Ember/theme.conf

    runHook postInstall
  '';

  meta = {
    description = "Fcitx5 Ember theme (warm monochrome with coral accent)";
    homepage = "https://github.com/ember-theme/ember";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}

