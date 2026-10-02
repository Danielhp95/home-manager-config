# Bibata Modern in colours of our own. nixpkgs' bibata-cursors packs the
# bitmaps upstream rendered for its three colourways (Amber, Classic, Ice), so
# those are all it has. This renders the bitmaps again from the same SVGs,
# which mark their three colours with pure green, blue and red, then packs
# them with upstream's own config: same shapes, hotspots, sizes and aliases.
#
# Returns a store path holding share/icons/<name>.
{
  lib,
  stdenvNoCC,
  bibata-cursors,
  clickgen,
  resvg,
}:
{
  name, # the theme's directory: what XCURSOR_THEME and `hyprctl setcursor` take
  # Bare hex. Amber is ff8300, ffffff, 001524.
  body, # the pointer's fill
  outline, # the band around it
  watch, # the disc behind the busy spinner
}:
let
  # upstream's render.json: placeholder -> colour
  tint = lib.concatStringsSep " " (
    lib.mapAttrsToList (from: to: "-e 's/#${from}/#${to}/gI'") {
      "00FF00" = body;
      "0000FF" = outline;
      "FF0000" = watch;
    }
  );
in
stdenvNoCC.mkDerivation {
  pname = lib.toLower name;
  inherit (bibata-cursors) version src;

  nativeBuildInputs = [
    clickgen
    resvg
  ];

  # The animated cursors are a directory of frames each; ctgen takes them
  # flat, as <cursor>-<frame>.png, which is how the frames are already named.
  buildPhase = ''
    runHook preBuild

    mkdir bitmaps
    for svg in svg/modern/*.svg svg/modern/*/*.svg; do
      sed ${tint} "$svg" > tinted.svg
      resvg tinted.svg "bitmaps/$(basename "$svg" .svg).png"
    done
    ctgen configs/normal/x.build.toml -p x11 -d bitmaps -n '${name}' \
      -c 'Bibata Modern, body #${body}'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -dm 0755 $out/share/icons
    cp -r themes/* $out/share/icons/

    runHook postInstall
  '';

  meta = bibata-cursors.meta // {
    description = "Bibata Modern cursors with a #${body} body";
  };
}
