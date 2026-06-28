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

    mkdir -pv $out/share/fcitx5/themes/Ember
    cp -v Ember.conf $out/share/fcitx5/themes/Ember/Ember.conf

    runHook postInstall
  '';

  meta = {
    description = "Fcitx5 Ember theme (warm monochrome with coral accent)";
    homepage = "https://github.com/ember-theme/ember";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}

