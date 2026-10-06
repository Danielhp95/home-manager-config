_:

{
  xdg = {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        # imv (imv.desktop) is installed too, if gThumb should go.
        "image/png" = [ "org.gnome.gThumb.desktop" ];
        "image/jpeg" = [ "org.gnome.gThumb.desktop" ];
        "image/webp" = [ "org.gnome.gThumb.desktop" ];
        "image/bmp" = [ "org.gnome.gThumb.desktop" ];
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
