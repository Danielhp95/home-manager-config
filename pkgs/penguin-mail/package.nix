# Penguin Mail (penguin-mail.com): mail and calendar for Gmail, Microsoft and
# IMAP accounts, in GTK. This is upstream's release tarball patched for the
# store, not a source build: only upstream's own builds carry the Google and
# Microsoft OAuth clients, and a copy built without them cannot sign in to
# either. Bound as pkgs.penguin-mail in ../overlay.nix.
#
# Build it alone with `nix build .#penguin-mail`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  webkitgtk_6_0,
  glib-networking,
  librsvg,
  adwaita-icon-theme,
  poppler-utils,
  hunspellDicts,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "penguin-mail";
  version = "1.0.2";

  # The sum the release's SHA256SUMS lists, which upstream signs with the key
  # FE3C 3B6E 699A F939 DC46 70DC F3A8 5303 5C3E 2B8E.
  src = fetchurl {
    url = "https://github.com/c9dev/penguin-mail/releases/download/v${finalAttrs.version}/penguin-mail-${finalAttrs.version}-x86_64.tar.gz";
    hash = "sha256-JAAB82GeKLudjpiwvFt052DLkoKayUy+ZAC0JJUrS8Y=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook4
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    gtk4
    libadwaita
    webkitgtk_6_0
    glib-networking # TLS for what WebKit loads
    librsvg # gdk-pixbuf's SVG loader: the app draws its own illustrations with it
    adwaita-icon-theme # its fallback when the icon theme lacks a symbol it uses
  ];

  dontConfigure = true;
  dontBuild = true;
  # Wrapped by hand below: only the app is a GTK program, and it does not
  # live in bin.
  dontWrapGApps = true;

  # The app updates itself wherever its binary is not under /usr and has no
  # `target` directory above it (a cargo build tree, to its eyes), and here
  # that would be a daily offer to install into the read-only store. So the
  # binary sits in a `target`, which is also what takes "Check for Updates"
  # out of Preferences.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/penguin-mail -t $out/lib/penguin-mail/target
    install -Dm755 bin/penguin-mail-cli -t $out/bin
    cp -r share $out/share
    runHook postInstall
  '';

  # The translations are looked for two directories above the binary, which
  # the `target` moved. pdftotext is what the assistant reads a PDF
  # attachment with, and DICPATH is the first place the composer looks for
  # a spelling dictionary (after it, ~/.local/share/hunspell and /usr).
  postFixup = ''
    makeWrapper $out/lib/penguin-mail/target/penguin-mail $out/bin/penguin-mail \
      "''${gappsWrapperArgs[@]}" \
      --set PENGUIN_MAIL_LOCALE_DIR $out/share/locale \
      --suffix PATH : ${lib.makeBinPath [ poppler-utils ]} \
      --suffix DICPATH : ${hunspellDicts.en_US}/share/hunspell
  '';

  meta = {
    description = "Mail and calendar for Linux";
    homepage = "https://penguin-mail.com";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "penguin-mail";
  };
})
