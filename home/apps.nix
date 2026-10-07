# Desktop applications that need no configuration of their own here.
{ pkgs, ... }:
{
  home.sessionVariables = {
    BROWSER = "firefox";
    # noctalia's runInTerminal would otherwise pick ghostty.
    TERMINAL = "kitty";
  };

  home.packages = [
    ### Communication
    pkgs.slack
    pkgs.telegram-desktop
    # For the launcher entry; services.nextcloud-client below runs the client.
    pkgs.nextcloud-client

    # Unstable as of this date, not pkgs.stable: an app on an older glibc than
    # the system's cannot load its Mesa, renders on the dGPU instead, and its
    # NVIDIA buffers abort Hyprland. Move the date along with nixpkgs.
    (pkgs.multiverse.at "2026-10-02").grayjay # video platform aggregator
    # From the release branch (pkgs.stable, pkgs/overlay.nix).
    pkgs.stable.discord

    ### Audio
    pkgs.crosspipe # visual audio mixer
    pkgs.pavucontrol

    pkgs.gnome-weather
    pkgs.adwaita-icon-theme # symbolic-icon fallback for GNOME apps (MoreWaita expects it)
    pkgs.gparted
    # Its "Open in Terminal" entry comes from nixos/default.nix.
    pkgs.nautilus
  ];

  # Started with the graphical session, in the tray.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
