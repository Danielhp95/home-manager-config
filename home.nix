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
    ./neovim
    ./rofi
    ./zellij
    ./atuin.nix
    #./kitty  # Kitty / alacritty break because of some GLX issues  (TODO: use nixGL?)
  ];

  programs.direnv.enable = true;
  programs.firefox.enable = true;
  programs.rio.enable = true;
  services.flameshot.enable = true;
  services.clipmenu.enable = true;

  home.packages = with pkgs; [
    # wezterm
    chromium
    powerline-fonts
    coreutils
    gzip
    gawk
    gnugrep
    nixgl.nixGLIntel
    nvd  # Nix version diff tool
    nushell

    # Latex stuff
    texlive.combined.scheme-full
    pandoc

    feh # image viewer
    # imv # image viewer BROKEN on Ubuntu 22.04
    ripgrep # better grep
    bat # Better cat
    ranger # File manager
    bottom # like htop but cooler
    tldr   # succint command explanations
    acpi  # To meassure laptop battery levels
    brightnessctl # Control brightness via CLI

    # For fun
    spotify
    mpv
    obsidian
    rmview  # Remarkable desktop client
    remarkable-mouse  # (Program: remouse) Using Remarkable as a mouse

    vlc
    # Audio
    helvum
    pamixer

    element-desktop
    zoom-us

  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
