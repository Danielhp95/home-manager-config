# yazi as the desktop's file dialog.
{ pkgs, ... }:
{
  # yazi as the file dialog of every app that asks the desktop portal for one
  # (the system side is xdg.portal in nixos/desktop.nix). The portal backend
  # runs file-chooser.nu, which opens yazi in a floating kitty: Enter on a file
  # picks it, q cancels. For a save, the suggested file is created as a
  # placeholder and hovered; move or rename it to save elsewhere, after which
  # Enter and q both save.
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.writers.writeNu "yazi-file-chooser" (builtins.readFile ./file-chooser.nu)}
    default_dir=$HOME
  '';

  # GTK apps draw their own file dialog unless told to ask the portal
  # (GTK_USE_PORTAL is GTK3's switch, GDK_DEBUG=portals GTK4's). It also sends
  # their "open this link" through the portal. Read at login.
  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    GDK_DEBUG = "portals";
  };
}
