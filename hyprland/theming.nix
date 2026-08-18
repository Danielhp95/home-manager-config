{pkgs, config, ...}:
let
  cursor-theme-name = "Bibata-Modern-Amber";
in
{
  gtk = {
    enable = true;
    # Pin legacy default: 26.05 changed gtk4.theme default from config.gtk.theme to null,
    # which would stop theming GTK4 apps with WhiteSur.
    gtk4.theme = config.gtk.theme;
    # GTK4/libadwaita dark mode is driven by the `color-scheme = prefer-dark` dconf
    # key below — that is the supported mechanism. The old `gtk-application-prefer-dark-theme`
    # GTK4 setting is rejected by libadwaita ("...is unsupported. Please use
    # AdwStyleManager:color-scheme instead"), and an `AdwStyleManager` settings.ini key
    # is not real ("Unknown key AdwStyleManager"). Keep the hint only for legacy GTK3 apps.
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    theme = {
      package = pkgs.whitesur-gtk-theme.override { themeVariants = [ "orange" ]; };
      name = "WhiteSur-Dark-orange";
    };

    iconTheme = {
      package = pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };

    font = {
      name = "Fira Code";
      size = 11;
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
    # back to its default look. (The GSK "Error 71" this used to be blamed on
    # is a GTK renderer issue, handled by GSK_RENDERER=gl in tuigreet.nix.)
    QT_QPA_PLATFORMTHEME = "gtk3";
    # Kept for GTK3 apps, but the "for nautilus" part of it was never going to
    # work and the note is corrected here rather than removed: nautilus is a
    # libadwaita app, and libadwaita ships its own stylesheet and ignores GTK
    # themes by design. Same for gnome-weather, gnome-calendar, decibels and
    # gthumb. What those *do* honour is the accent-color key below.
    GTK_THEME = "WhiteSur-Dark-orange";
  };

  dconf.settings = {
    "org/gnome/desktop/interface".cursor-theme = cursor-theme-name;
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
    # libadwaita >= 1.6 reads its accent from here (1.9.3 is what is
    # installed). The schema default is 'blue', which is what every GNOME app
    # was drawing with — visibly foreign next to the Ember/WhiteSur orange.
    # The key is an enum of nine named colours, not a hex value, so 'orange'
    # is as close to palette.nix `accent` as this mechanism gets; it cannot be
    # pointed at the exact coral.
    "org/gnome/desktop/interface".accent-color = "orange";
  };
}
