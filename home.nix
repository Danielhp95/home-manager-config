{
  inputs,
  stableWithUnfree,
  grayjayStable,
  unstableWithUnfree,
  pkgs,
  lib,
  ...
}:

{

  home.stateVersion = "24.05";

  home.sessionVariables = {
    BROWSER = "firefox";
  };

  # To allow bluetooth devices buttons to control media things (like stop / play)
  services.mpris-proxy.enable = true;

  imports = [
    ./starship
    ./zsh
    ./tmux
    ./zellij

    ./yazi

    ./zathura.nix
    ./git
    ./menu_launchers

    ./terminal
    ./terminal/television.nix
    ./kitty

    ./hyprland
    ./status_bars

    ./sony_ai

    ./notifications

    ./flameshot

    ./writing.nix
    ./default_applications.nix
  ];

  khome.desktop.swww = {
    enable = true;
    wallpaperDirs = [
      "~/nix_config/wallpapers"
    ]; # TODO: create an env variable based on this and use that everywhere else
  };

  services.clipmenu.enable = true;
  programs.mpv = {
    enable = true;
    config = {
      ytdl-format = "bestvideo+bestaudio";
      keep-open = true; # Don't close mpv when video is done
    };
  };

  home.packages = with pkgs; [
    ### Browsers
    chromium
    nvd # Nix version diff tool
    nushell

    ### Style
    pywal # Colorscheme generator

    ### Communication
    # (writeScriptBin "slack" ''
    #   ${slack}/bin/slack --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3
    # '')
    slack
    telegram-desktop
    element-desktop

    zoom-us

    openconnect

    ### Photography
    # ansel

    ## Videography
    (writeScriptBin "davinci" ''
      QT_QPA_PLATFORM=xcb ${davinci-resolve}/bin/davinci-resolve
    '')

    ### Basic utilities
    ripgrep # better grep
    bat # Better cat
    zenith # better top
    tldr # succint command explanations
    acpi # To meassure laptop battery levels
    brightnessctl # Control brightness via CLI
    coreutils
    gzip
    gawk
    gnugrep
    unzip
    wget
    ffmpeg
    zip

    ### Media viewing
    # video
    vlc
    mpv

    # music / video
    spotify
    grayjay

    # Images
    imv # Lightweight
    gthumb # Viewer for multiple images

    # Best youtube downloader
    yt-dlp
    ###

    ### debugging utils
    lnav # Use it to pipe `journalctl | lnav` for syntax highlighing / filtering
    pciutils # For `lspci` command.
    lshw # list hardware. For instance `lshw -c display` shows all graphics cards
    nvtopPackages.full # Better `nvidia-smi` that also supports AMD GPUs
    powertop # Analyze power consumption for intel based processors

    ### Audio
    helvum # visual audio mixer
    pamixer # cli for pulseaudio
    pavucontrol # not working!

    translate-shell

    # THE nvim
    inputs.danvim.packages.x86_64-linux.nvimStable

    # Weather app
    mousam
    gnome-weather

    gnome-calendar
    gparted
    decibels # audio playing with nice waveform graphics

    nautilus
    nautilus-open-any-terminal
    lingot # Instrument tuner

    # Process management
    bottom

    # File sharing (Like AirDrop)
    localsend

    # nix cli helper, useful for switching etc
    nh
    nvidia-docker

    bluetui # Bluetooth tui

    gnome-session

    unstableWithUnfree.firefox
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
