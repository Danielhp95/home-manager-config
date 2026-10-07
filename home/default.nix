# The Home Manager side: one module per program or group of programs. The
# order of this list is part of the build (it orders home.packages): add new
# modules at the end.
_: {
  # The release this home was first set up with; never bump it.
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  imports = [
    ./fcitx5

    ./starship
    ./shell
    ./tmux

    ./yazi

    ./zathura.nix
    ./git
    ./vicinae

    # Apps that draw their own UI, so GTK/Qt theming does not reach them.
    ./firefox
    ./chromium.nix
    ./element.nix
    ./spotify.nix

    ./lnav

    ./terminal

    ./claude-code
    ./kitty
    ./ghostty
    ./ipython
    ./matplotlib.nix

    ./hyprland
    ./noctalia

    ./sony-ai.nix

    ./writing.nix
    ./default-applications.nix

    ./apps.nix
    ./media.nix
    ./gpg.nix
    ./nix-tools.nix
    ./hardware-tools.nix
  ];
}
