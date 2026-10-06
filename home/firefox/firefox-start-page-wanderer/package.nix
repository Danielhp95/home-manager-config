# The start page and its backend, buildable (tests included, in checkPhase)
# without evaluating Home Manager:
#   nix build .#start-page
{
  lib,
  cormorant,
  fetchurl,
  imagemagick,
  nodejs,
  python3,
  replaceVars,
  runCommand,
  stdenvNoCC,
  writeText,
  theme,
}:

let
  # `theme`, never `palette`, as the argument: nixpkgs has a package called
  # palette, and callPackage would fill an argument of that name with it.
  palette = theme;
  shared = import ./shared.nix;
  inherit (theme) colour;

  ramp = palette.extra.artRamp;
  brightestSky = lib.last ramp;
  art =
    # Text must stay the lightest thing on the page.
    assert lib.assertMsg (
      colour.luminance brightestSky < colour.luminance palette.fg
    ) "start page: extra.artRamp's last stop #${brightestSky} is not darker than fg #${palette.fg}";
    import ./art.nix {
      inherit
        fetchurl
        imagemagick
        runCommand
        ramp
        ;
    };

  # As with ../userChrome.css: nix owns the palette, the stylesheet stays plain.
  paletteCss = writeText "palette.css" ''
    /* Generated from nix_config's palette/ — do not edit. */
    :root {
    ${colour.cssVars "ember" palette.hash.slots}  --ember-fog-rgb: ${colour.rgbSpaces palette.extra.fog};
      --mono: "${theme.fonts.monoWide}", "JetBrains Mono", ui-monospace, monospace;
    }
  '';

  # The inline favicon: the page's bg, a peak in the painting's mid-tone, the
  # sun in accent. Bare hex: each follows a %23 in the data URI.
  indexHtml = replaceVars ./page/index.html {
    faviconBg = palette.bg;
    faviconPeak = builtins.elemAt ramp 2;
    faviconSun = palette.accent;
  };

  aliasesJson = writeText "aliases.json" (builtins.toJSON shared.searchAliases);
in
rec {
  inherit art;
  # For lib/checks.nix: the variables the page's stylesheets may use.
  inherit paletteCss;

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
      cp ${indexHtml} $out/index.html
      cp style.css app.js search.js $out/assets/
      cp ${paletteCss} $out/assets/palette.css
      cp ${aliasesJson} $out/assets/aliases.json
      cp ${art} $out/assets/wanderer.jpg

      # Only the two faces the page actually uses, served from the page's own
      # origin: the clock must not depend on fontconfig finding anything.
      cp ${cormorant}/share/fonts/truetype/CormorantGaramond-Regular.ttf $out/assets/fonts/
      cp ${cormorant}/share/fonts/truetype/CormorantGaramond-Italic.ttf $out/assets/fonts/

      runHook postInstall
    '';

    meta = {
      description = "Static start page: Friedrich's Wanderer, graded into the palette, over a live dashboard";
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
