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
  qt = {
    enable = true;
    theme = {
      package = pkgs.whitesur-qt-theme.override { themeVariants = [ "orange" ]; };
      name = "WhiteSur-Dark-orange";
    };
    iconTheme = {
      package = pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };
  };
  dconf.settings = {
    "org/gnome/desktop/interface".cursor-theme = cursor-theme-name;
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
