{pkgs, ...}:
let
  cursor-theme-name = "Bibata-Modern-Amber";
in
{
  gtk = {
    enable = true;
    gtk4.extraConfig = {
      # TODO: This still places things under [Settings] and we want this to be placed under [AdwStyleManager]. How do we do it?
      AdwStyleManager = "color-scheme=ADW_COLOR_SCHEME_PREFER_DARK";
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
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

  # Cursor. This might not be necessary with hyprland 0.41
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = cursor-theme-name;
    size = 20;
  };

  home.sessionVariables = {
    # TODO: this was introduced in November 2024, can we remove this at some point?
    # To surpress error: GSK-message Error 71 (Protocol error) dispatching to Wayland display.
    QT_QPA_PLATFORMTHEME = "gtk4";
    GTK_THEME = "WhiteSur-Dark-orange"; # For nautilus. Not working
  };

  dconf.settings = {
    "org/gnome/desktop/interface".cursor-theme = cursor-theme-name;
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
