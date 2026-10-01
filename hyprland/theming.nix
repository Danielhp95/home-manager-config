{
  pkgs,
  config,
  lib,
  ...
}:
let
  p = import ../palette.nix;
  m = p.meta;
  f = import ../fonts.nix;
  css = import ../gtk-css.nix p;
in
{
  gtk = {
    enable = true;
    # The 26.05 default is null, which would leave GTK4 apps unthemed. Themes that
    # must not be imported as user CSS (adw-gtk3) say so in the palette's meta.
    gtk4.theme = if m.gtk.gtk4Import then config.gtk.theme else null;
    # With no import HM drops gtk-theme-name from gtk-4.0/settings.ini; plain GTK4
    # apps (Chromium's frame) still need the name to find <theme>/gtk-4.0/gtk.css.
    gtk4.extraConfig = lib.mkIf (!m.gtk.gtk4Import) { gtk-theme-name = m.gtk.name; };
    # GTK3 prefer-dark plus the dconf color-scheme that GTK4/libadwaita follow.
    # Not on gtk4: libadwaita rejects its settings.ini key.
    gtk3.colorScheme = "dark";
    theme = {
      package = m.gtk.package pkgs;
      name = m.gtk.name;
    };
    # Named-colour overrides generated from the palette (../gtk-css.nix).
    gtk3.extraCss = lib.mkIf m.gtk.paletteCss.gtk3 css.css3;
    gtk4.extraCss = lib.mkIf m.gtk.paletteCss.gtk4 css.css4;

    iconTheme = {
      package = m.icons.package pkgs;
      name = m.icons.name;
    };

    font = {
      name = f.ui;
      size = f.uiSize;
    };
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    package = m.cursor.package pkgs;
    inherit (m.cursor) name size;
  };

  home.sessionVariables = {
    # Qt follows the GTK theme. Not "gtk4": no such plugin, Qt silently ignores it.
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  dconf.settings = {
    # libadwaita's accent (default 'blue'): an enum of named colours, not hex.
    "org/gnome/desktop/interface".accent-color = m.adwaitaAccent;
    # GNOME's monospace and document fonts; gtk.font only sets font-name.
    "org/gnome/desktop/interface".monospace-font-name = "${f.mono} ${toString f.uiSize}";
    "org/gnome/desktop/interface".document-font-name = "${f.ui} ${toString f.uiSize}";
  };
}
