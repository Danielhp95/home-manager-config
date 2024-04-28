{ inputs, config, pkgs, environment, ... }:

{

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "24.05";
  imports = [
    ./starship
    ./zsh
    ./tmux
    ./zellij

    ./zathura.nix
    ./git
    ./menu_launchers

    ./neovim
    ./terminal
    ./atuin.nix

    ./hyprland
    ./sway

    ./sony_ai
    ./pulse_vpn.nix

    ./ags
    ./notifications
  ];

  khome.desktop.swww = {
    enable = true;
    wallpaperDirs = [ "~/nix_config/wallpapers" ];  # TODO: create an env variable based on this and use that everywhere else
  };

  programs.eww-hyprland.enable = true;

  programs.firefox.enable = true;
  # programs.rio.enable = true;
  # services.flameshot.enable = true;
  services.clipmenu.enable = true;

  home.packages = with pkgs; [
    chromium
    powerline-fonts
    coreutils
    gzip
    gawk
    gnugrep
    nvd  # Nix version diff tool
    nushell

    # Communication
    slack
    telegram-desktop
    element-desktop
    zoom-us

    # art
    ansel
    # inputs.stable.legacyPackages.x86_64-linux.davinci-resolve
    davinci-resolve
    steam
    gamescope  # micro compositor by steam

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
    nvtopPackages.full  # Better `nvidia-smi` that also supports AMD GPUs

    # Audio
    helvum
    pamixer
    pavucontrol

    translate-shell

    # Colorscheme generator
    pywal
    pywalfox-native  # addon for firefox to read colorscheme from pywal

    unzip
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
