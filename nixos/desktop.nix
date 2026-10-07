# What the graphical session needs from the system: programs that install
# setuid helpers, udev rules or firewall holes, the desktop portals, and the
# services a GNOME desktop would bring.
{ pkgs, ... }:
{
  programs.ydotool.enable = true;

  # Backend for noctalia's screen_recorder plugin; the module adds the
  # setcap'd gsr-kms-server wrapper that KMS capture needs.
  programs.gpu-screen-recorder.enable = true;

  programs.steam.enable = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  # openFirewall: 53317 TCP + UDP, for receiving.
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  security.polkit.enable = true;

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true; # home-manager's portal module asserts on the pathsToLink this sets
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk # Settings and the rest ("hyprland;gtk")
      pkgs.xdg-desktop-portal-termfilechooser # file dialogs: yazi (home/yazi/file-chooser.nix)
    ];
    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  # Session start: greeter script (./greeter.nix) -> start-hyprland;
  # Hyprland's start hook pushes the env to systemd (home/hyprland/default.nix).
  # Session daemons must be units WantedBy=graphical-session.target, never
  # exec-once; leave hyprland.systemd.extraCommands at the module default.

  # Services a GNOME desktop would normally enable
  services.gvfs.enable = true; # yazi/nautilus: MTP, network shares (see home/yazi/default.nix)
  services.udisks2.enable = true; # yazi mount menu
  services.gnome.gnome-keyring.enable = true; # Secret Service; unlocked at login by greetd's PAM stack
  services.gnome.glib-networking.enable = true; # TLS for libsoup (GNOME apps such as gnome-weather)
  services.gnome.evolution-data-server.enable = true; # the calendar store gnome-calendar reads (home/apps.nix)
  services.gnome.gnome-online-accounts.enable = true; # its Google and Nextcloud sign-in
  services.geoclue2.enable = true; # maps/weather location; demo agent replaces gnome-shell's
  services.gnome.at-spi2-core.enable = true; # a11y bus; silences GTK warnings

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];

    desktopManager.runXdgAutostartIfNone = true;
    desktopManager.session = [
      {
        manage = "window";
        name = "Hyprland";
        start = "Hyprland";
      }
    ];
  };
}
