_:

# --gtk-version=4 draws Chromium's frame, menus and dialogs with GTK4, where
# WhiteSur lives; it also needs the one-time profile setting
# chrome://settings/appearance -> Theme -> Use GTK. The Wayland flags come from
# nixpkgs' wrapper via NIXOS_OZONE_WL.

{
  programs.chromium = {
    enable = true;

    commandLineArgs = [
      "--gtk-version=4"
    ];
  };
}
