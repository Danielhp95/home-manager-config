{ ... }:

# Chromium draws its own UI, but it *can* be told to render its frame, menus
# and dialogs with GTK4 — which is where WhiteSur-Dark-orange lives (the GTK4
# variant is wired up in hyprland/theming.nix). Without --gtk-version=4 it
# falls back to GTK3 and looks like a different desktop.
#
# For the theme to actually be picked, Chromium's own Appearance setting must
# be "GTK" (chrome://settings/appearance -> Theme -> Use GTK). That is stored
# in the profile, not in a flag, so it is a one-time manual step.
#
# Native Wayland needs no flags here: nixpkgs' chromium wrapper already adds
# --ozone-platform-hint=auto and --enable-features=WaylandWindowDecorations
# whenever NIXOS_OZONE_WL is set, as it is in this session.

{
  programs.chromium = {
    enable = true;

    commandLineArgs = [
      "--gtk-version=4"
    ];
  };
}
