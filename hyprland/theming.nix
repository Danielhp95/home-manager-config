{pkgs, config, ...}:
let
  cursor-theme-name = "Bibata-Modern-Amber";
  f = import ../fonts.nix;
in
{
  gtk = {
    enable = true;
    # The 26.05 default is null, which would leave GTK4 apps unthemed.
    gtk4.theme = config.gtk.theme;
    # GTK3 prefer-dark plus the dconf color-scheme that GTK4/libadwaita follow.
    # Not on gtk4: libadwaita rejects its settings.ini key.
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
    # Qt follows the GTK theme. Not "gtk4": no such plugin, Qt silently ignores it.
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  dconf.settings = {
    # libadwaita's accent (default 'blue'). An enum of named colours, not hex,
    # so 'orange' is the closest to palette.nix `accent`.
    "org/gnome/desktop/interface".accent-color = "orange";
    # GNOME's monospace and document fonts; gtk.font only sets font-name.
    "org/gnome/desktop/interface".monospace-font-name = "${f.mono} ${toString f.uiSize}";
    "org/gnome/desktop/interface".document-font-name = "${f.ui} ${toString f.uiSize}";
  };
}
