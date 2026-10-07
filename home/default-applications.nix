{ config, lib, ... }:
let
  inherit (config.home.sessionVariables) EDITOR TERMINAL;

  types = prefix: map (name: "${prefix}/${name}");
  handledBy = app: mimeTypes: lib.genAttrs mimeTypes (_: [ app ]);

  # What $EDITOR opens. xdg-open matches a type by its exact name, with no
  # fallback from a subtype to text/plain, so each one is spelled out, and an
  # alias (text/x-markdown, application/x-yaml) sits beside its real name.
  # A type missing here still reaches the editor from GTK apps, which do fall
  # back; from xdg-open it lands in $BROWSER.
  textTypes =
    types "text" [
      "plain"
      "markdown"
      "x-markdown"
      "x-readme"
      "x-rst"
      "org"
      "x-log"
      "x-changelog"
      "x-authors"
      "x-copying"
      "x-install"
      # Writing
      "x-tex"
      "x-bibtex"
      "vnd.typst"
      # Data and configuration
      "csv"
      "tab-separated-values"
      "xml"
      "x-systemd-unit"
      "x-dbus-service"
      "x-dockerfile"
      "x-patch"
      "x-diff"
      # Code
      "x-shellscript"
      "x-sh"
      "x-python"
      "x-python3"
      "x-nix"
      "x-lua"
      "rust"
      "x-go"
      "x-c"
      "x-csrc"
      "x-chdr"
      "x-c++src"
      "x-c++hdr"
      "x-moc"
      "x-java"
      "x-kotlin"
      "x-scala"
      "x-csharp"
      "x-haskell"
      "x-ocaml"
      "x-elixir"
      "x-erlang"
      "x-common-lisp"
      "x-scheme"
      "x-emacs-lisp"
      "julia"
      "x-matlab"
      "x-fortran"
      "x-pascal"
      "x-tcl"
      "tcl"
      "javascript"
      "css"
      "x-scss"
      "x-qml"
      "vnd.graphviz"
      "x-makefile"
      "x-cmake"
      "x-meson"
    ]
    ++ types "application" [
      "json"
      "json5"
      "yaml"
      "x-yaml"
      "toml"
      "xml"
      "sql"
      "x-desktop"
      "x-zerosize" # an empty file
      "x-shellscript"
      "x-nuscript"
      "x-fishscript"
      "javascript"
      "x-javascript"
      "typescript"
      "x-perl"
      "x-ruby"
      "x-php"
    ];

  # Every picture format gThumb reads. Left to themselves, GIF went to
  # Chromium and SVG, TIFF and JPEG XL to imv.
  # imv (imv.desktop) is installed too, if gThumb should go.
  imageTypes = types "image" [
    "png"
    "jpeg"
    "webp"
    "bmp"
    "gif"
    "svg+xml"
    "tiff"
    "jxl"
  ];
in
{
  xdg = {
    enable = true;
    mime.enable = true;

    # $EDITOR in a window of its own, in place of the entry the editor's
    # package ships (same file name, and Home Manager's wins). That one says
    # Terminal=true: xdg-open ignores the key and starts nvim with no terminal,
    # and GLib (GTK apps, Firefox, the portal) refuses to start it without a
    # terminal it knows, which kitty is not. Either way a text file opened
    # from an app opened nothing.
    desktopEntries.${EDITOR} = {
      name = EDITOR;
      genericName = "Text Editor";
      exec = "${TERMINAL} -e ${EDITOR} %F";
      icon = EDITOR;
      categories = [
        "Utility"
        "TextEditor"
        "Development"
      ];
      mimeType = textTypes;
    };

    mimeApps = {
      enable = true;
      defaultApplications =
        handledBy "${EDITOR}.desktop" textTypes
        // handledBy "org.gnome.gThumb.desktop" imageTypes
        // {
          "application/pdf" = [ "org.pwmt.zathura.desktop" ];
          "x-scheme-handler/mailto" = [ "io.github.c9dev.PenguinMail.desktop" ];
          "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
          "x-scheme-handler/chrome" = [ "firefox.desktop" ];
          "text/html" = [ "firefox.desktop" ];
          "application/x-extension-htm" = [ "firefox.desktop" ];
          "application/x-extension-html" = [ "firefox.desktop" ];
          "application/x-extension-shtml" = [ "firefox.desktop" ];
          "application/xhtml+xml" = [ "firefox.desktop" ];
          "application/x-extension-xhtml" = [ "firefox.desktop" ];
          "application/x-extension-xht" = [ "firefox.desktop" ];
          "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
        };
    };
  };
}
