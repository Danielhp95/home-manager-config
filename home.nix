{ config, pkgs, environment, ... }:

{

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "22.11";
  imports = [
    ./starship
    ./zsh
    ./tmux
    ./zathura.nix
    ./git
    ./nvim/neovim.nix
    ./rofi
    ./zellij
    #./kitty  # Kitty / alacritty break because of some GLX issues
  ];

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    powerline-fonts
    coreutils
    gzip
    gawk
    gnugrep

    # Latex stuff
    texlive.combined.scheme-full
    pandoc

    feh # image viewer
    # imv # image viewer BROKEN on Ubuntu 22.04
    ripgrep # better grep
    exa # Better ls
    bat # Better cat
    ranger # File manager
    bottom # like htop but cooler
    tldr   # succint command explanations
    nvfetcher # To get nvim plugins (could expand to other things)
    acpi  # To meassure laptop battery levels

    # For fun
    spotify
    mpv
    obsidian

    # Audio
    helvum
    pamixer
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
