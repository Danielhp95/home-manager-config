{ ... }:

# A lot of these values were taken from a ~/.config/mimeapps.list tht was on my system
{
  xdg = {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = ["org.pwmt.zathura.desktop"];
        "image/png" = ["org.gnome.gThumb.desktop"];  # Can I get imv?
        "image/jpeg" = ["org.gnome.gThumb.desktop"];  # Can I get imv?
        "image/webp" = ["org.gnome.gThumb.desktop"];  # Can I get imv?
        "image/bmp" = ["org.gnome.gThumb.desktop"];  # Can I get imv?
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/http" = ["firefox.desktop"];
        "x-scheme-handler/https" = ["firefox.desktop"];
        "x-scheme-handler/chrome" = ["firefox.desktop"];
        "text/html" = ["firefox.desktop"];
        "application/x-extension-htm" = ["firefox.desktop"];
        "application/x-extension-html" = ["firefox.desktop"];
        "application/x-extension-shtml" = ["firefox.desktop"];
        "application/xhtml+xml" = ["firefox.desktop"];
        "application/x-extension-xhtml" = ["firefox.desktop"];
        "application/x-extension-xht" = ["firefox.desktop"];
        "x-scheme-handler/tonsite" = ["org.telegram.desktop.desktop"];
      };
      associations.added = {
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop;"];
        "x-scheme-handler/http" = ["firefox.desktop;"];
        "x-scheme-handler/https" = ["firefox.desktop;"];
        "x-scheme-handler/chrome" = ["firefox.desktop;"];
        "text/html" = ["firefox.desktop;"];
        "application/x-extension-htm" = ["firefox.desktop;"];
        "application/x-extension-html" = ["firefox.desktop;"];
        "application/x-extension-shtml" = ["firefox.desktop;"];
        "application/xhtml+xml" = ["firefox.desktop;"];
        "application/x-extension-xhtml" = ["firefox.desktop;"];
        "application/x-extension-xht" = ["firefox.desktop;"];
        "x-scheme-handler/tonsite" = ["org.telegram.desktop.desktop;"];
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["firefox.desktop;"];
      };
    };
  };
}
