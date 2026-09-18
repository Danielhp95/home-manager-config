# The two store paths behind the start page: the page itself and the backend
# that serves it. Split out of ./default.nix so both can be built (and their
# test suites run) without evaluating the whole Home Manager configuration:
#
#   nix build --impure --expr 'let p = import <nixpkgs> {}; in
#     (p.callPackage ./firefox/firefox-start-page-wanderer/package.nix {}).page'
#
# Both derivations run their tests in checkPhase, so a broken parser or a
# broken search-alias rule fails `nh os build` instead of the new tab.
{
  lib,
  cormorant,
  fetchurl,
  imagemagick,
  nodejs,
  python3,
  runCommand,
  stdenvNoCC,
  writeText,
}:

let
  # Imported rather than taken as arguments: nixpkgs has a package called
  # `palette`, and callPackage would inject *that* over a defaulted argument
  # of the same name. It does, and the failure is a puzzling "attribute 'hash'
  # missing" a long way from here.
  palette = import ../../palette.nix;
  shared = import ./shared.nix;

  art = import ./art.nix { inherit fetchurl imagemagick runCommand; };

  # bgDeep -> --ember-bg-deep. Digits and punctuation pass through, since for
  # them toUpper and toLower are both the character itself.
  toKebab =
    name:
    lib.concatMapStrings (
      char:
      if char == lib.toUpper char && char != lib.toLower char then "-${lib.toLower char}" else char
    ) (lib.stringToCharacters name);

  # The same trick ../userChrome.css uses: nix owns the palette, the
  # stylesheet stays a plain stylesheet with no interpolation inside it.
  paletteCss = writeText "palette.css" ''
    /* Generated from ../../palette.nix — do not edit. */
    :root {
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: "  --ember-${toKebab name}: ${value};\n") (
        lib.filterAttrs (_: value: builtins.isString value) palette.hash
      )
    )}}
  '';

  aliasesJson = writeText "aliases.json" (builtins.toJSON shared.searchAliases);
in
rec {
  inherit art;

  page = stdenvNoCC.mkDerivation {
    pname = "firefox-start-page-wanderer-page";
    version = "1.0";
    src = ./page;

    dontConfigure = true;
    dontBuild = true;

    # nodejs is a *check* input: nothing in the served page needs it.
    nativeCheckInputs = [ nodejs ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      ALIASES_JSON=${aliasesJson} node --test search.test.js
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/assets/fonts
      cp index.html $out/
      cp style.css app.js search.js $out/assets/
      cp ${paletteCss} $out/assets/palette.css
      cp ${aliasesJson} $out/assets/aliases.json
      cp ${art} $out/assets/wanderer-ember.jpg

      # Only the two faces the page actually uses, served from the page's own
      # origin: the clock must not depend on fontconfig finding anything.
      cp ${cormorant}/share/fonts/truetype/CormorantGaramond-Regular.ttf $out/assets/fonts/
      cp ${cormorant}/share/fonts/truetype/CormorantGaramond-Italic.ttf $out/assets/fonts/

      runHook postInstall
    '';

    meta = {
      description = "Static start page: Friedrich's Wanderer, Ember-graded, over a live dashboard";
      platforms = lib.platforms.all;
    };
  };

  service = stdenvNoCC.mkDerivation {
    pname = "firefox-start-page-wanderer";
    version = "1.0";
    src = ./service;

    # In buildInputs rather than nativeBuildInputs so patchShebangs rewrites
    # `#!/usr/bin/env python3` to this exact interpreter.
    buildInputs = [ python3 ];

    dontConfigure = true;
    dontBuild = true;

    nativeCheckInputs = [ python3 ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      python3 -m unittest discover -s . -p 'test_*.py'
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 firefox-start-page-wanderer.py $out/bin/firefox-start-page-wanderer
      runHook postInstall
    '';

    meta = {
      description = "Local backend for the Wanderer start page (weather, machine, code, todo)";
      mainProgram = "firefox-start-page-wanderer";
      platforms = lib.platforms.linux;
    };
  };
}
