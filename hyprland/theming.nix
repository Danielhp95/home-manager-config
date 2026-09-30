{pkgs, config, ...}:
let
  cursor-theme-name = "Bibata-Modern-Amber";
  f = import ../fonts.nix;
in
{
  gtk = {
    enable = true;
    # Pin legacy default: 26.05 changed gtk4.theme default from config.gtk.theme to null,
    # which would stop theming GTK4 apps with WhiteSur.
    gtk4.theme = config.gtk.theme;
    # Dark mode. For GTK3 this writes gtk-application-prefer-dark-theme to
    # settings.ini, plus the `color-scheme = prefer-dark` dconf key, which is
    # what GTK4/libadwaita follow. Set on gtk3 only: libadwaita rejects the
    # GTK4 settings.ini key ("...is unsupported. Please use
    # AdwStyleManager:color-scheme instead").
    gtk3.colorScheme = "dark";
    theme = {
      package = pkgs.whitesur-gtk-theme.override { themeVariants = [ "orange" ]; };
      name = "WhiteSur-Dark-orange";
    };

    iconTheme = {
      package = pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };

    font = {
      name = f.ui;
      size = f.uiSize;
    };
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = cursor-theme-name;
    size = 20;
  };

  home.sessionVariables = {
    # Make Qt apps follow the GTK theme. Only a "gtk3" platform-theme plugin
    # exists (libqgtk3.so) — "gtk4" is not a valid value and Qt silently fell
    # back to its default look.
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  dconf.settings = {
    # libadwaita >= 1.6 reads its accent from here (1.9.3 is what is
    # installed). The schema default is 'blue', which is what every GNOME app
    # was drawing with — visibly foreign next to the Ember/WhiteSur orange.
    # The key is an enum of nine named colours, not a hex value, so 'orange'
    # is as close to palette.nix `accent` as this mechanism gets; it cannot be
    # pointed at the exact coral.
    "org/gnome/desktop/interface".accent-color = "orange";
    # GNOME's monospace and document fonts, from fonts.nix. Unset, they kept
    # whatever the dconf database held: 'Hack 10', which is not installed, so
    # fontconfig handed "monospace" text a proportional face.
    "org/gnome/desktop/interface".monospace-font-name = "${f.mono} ${toString f.uiSize}";
    "org/gnome/desktop/interface".document-font-name = "${f.ui} ${toString f.uiSize}";
  };
}
