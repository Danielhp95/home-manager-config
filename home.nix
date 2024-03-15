{ config, pkgs, environment, ... }:

{

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "24.05";
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
    ./hyprland
    ./sway
    ./eww
    ./pulse_vpn.nix
  ];

  khome.desktop.swww = {
    enable = true;
    wallpaperDirs = [ "~/Pictures/hangmoon" ];
  };


  programs.firefox.enable = true;
  # programs.rio.enable = true;
  services.flameshot.enable = true;
  services.clipmenu.enable = true;

  home.packages = with pkgs; [
    wezterm
    chromium
    powerline-fonts
    coreutils
    gzip
    gawk
    gnugrep
    nvd  # Nix version diff tool
    nushell

    fuzzel

    # Communication
    slack
    telegram-desktop
    element-desktop
    zoom-us

    # art
    ansel
    davinci-resolve
    steam

    # Latex stuff
    texlive.combined.scheme-full
    pandoc

    feh # image viewer
    imv # image viewer
    hyprpaper # crappy wallpaper manager for hyprland
    # swww # wallpaper manager

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
    # obsidian
    rmview  # Remarkable desktop client
    remarkable-mouse  # (Program: remouse) Using Remarkable as a mouse

    vlc

    # debugging utils
    lnav  # Use it to pipe `journalctl | lnav` for syntax highlighing / filtering
    pciutils  # For `lspci` command
    lshw  # list hardware. For instance `lshw -c display` shows all graphics cards
    nvtop  # Better `nvidia-smi` that also supports AMD GPUs

    # Audio
    helvum
    pamixer
    pavucontrol

    # authenticators
    awscli2
    amazon-ecr-credential-helper

    translate-shell

    # Colorscheme generator
    pywal
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
