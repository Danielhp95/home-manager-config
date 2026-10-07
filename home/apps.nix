# Desktop applications that need no configuration of their own here.
{ pkgs, ... }:
{
  home.sessionVariables = {
    BROWSER = "firefox";
    # What noctalia's runInTerminal runs, and the terminal-window entries in
    # ./default-applications.nix and ./yazi/file-manager.nix.
    TERMINAL = "kitty";
  };

  # The same choice for whatever follows the xdg-terminal-exec convention:
  # vicinae, and GLib when a GTK app starts a Terminal=true entry. Without it
  # vicinae takes the first terminal entry it finds, and kitty-open.desktop
  # (`kitty +open`) is one.
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "kitty.desktop" ];
  };

  home.packages = with pkgs; [
    ### Communication
    slack

    telegram-desktop
    # Mail and calendar; the mailto: handler (./default-applications.nix).
    penguin-mail
    # For the launcher entry; services.nextcloud-client below runs the client.
    nextcloud-client

    # Unstable as of this date, not pkgs.stable: an app on an older glibc than
    # the system's cannot load its Mesa, renders on the dGPU instead, and its
    # NVIDIA buffers abort Hyprland. Move the date along with nixpkgs.
    (multiverse.at "2026-10-02").grayjay # video platform aggregator
    # From the release branch (pkgs.stable, pkgs/overlay.nix).
    stable.discord

    ### Audio
    crosspipe # visual audio mixer
    pavucontrol

    gnome-weather
    # Its calendars live in evolution-data-server (nixos/desktop.nix).
    gnome-calendar
    # Where its accounts are added, in place of GNOME Settings.
    gnome-online-accounts-gtk
    adwaita-icon-theme # symbolic-icon fallback for GNOME apps (MoreWaita expects it)
    gparted
    # Its "Open in Terminal" entry comes from nixos/desktop.nix.
    nautilus
  ];

  # Started with the graphical session, in the tray.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
