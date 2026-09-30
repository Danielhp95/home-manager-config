# The start page and its backend, buildable (tests included, in checkPhase)
# without evaluating Home Manager:
#   nix build --impure --expr 'let p = import <nixpkgs> {}; in
#     (p.callPackage ./firefox/firefox-start-page-wanderer/package.nix {}).page'
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
  # Imported, not an argument: callPackage would inject nixpkgs' own `palette`
  # package instead ("attribute 'hash' missing").
  palette = import ../../palette.nix;
  shared = import ./shared.nix;

  art = import ./art.nix { inherit fetchurl imagemagick runCommand; };

  # bgDeep -> bg-deep; digits and punctuation pass through.
  toKebab =
    name:
    lib.concatMapStrings (
      char:
      if char == lib.toUpper char && char != lib.toLower char then "-${lib.toLower char}" else char
    ) (lib.stringToCharacters name);

  # As with ../userChrome.css: nix owns the palette, the stylesheet stays plain.
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
