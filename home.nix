{
  inputs,
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

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableExtraSocket = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    pinentry = {
      package = pkgs.pinentry-all;
      # Use pinentry-gnome3 for GUI environments instead of curses
      program = "pinentry-curses";
    };
  };

  # Ensure GPG agent starts with systemd user session
  systemd.user.sockets.gpg-agent = {
    Unit.PartOf = [ "graphical-session.target" ];
    Socket.SocketMode = "0600";
    Install.WantedBy = [ "sockets.target" ];
  };

  imports = [
    ./starship
    ./zsh
    ./tmux

    ./yazi

    ./zathura.nix
    ./git
    ./menu_launchers

    ./terminal
    ./terminal/television.nix
    ./terminal/nushell.nix
    ./kitty
    ./ghostty

    ./hyprland
    ./status_bars
    ./noctalia

    ./sony_ai

    ./flameshot

    ./writing.nix
    ./default_applications.nix
    # Import voxtype HM module
    inputs.voxtype.homeManagerModules.default
  ];

  # Wallpaper managaer
  services.awww.enable = true;

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

    ### Style
    pywal # Colorscheme generator

    ### Communication
    slack
    telegram-desktop
    element-desktop

    # zoom-us

    # grayjay # video platform aggregator

    openconnect

    ## Videography
    (writeScriptBin "davinci" ''
      QT_QPA_PLATFORM=xcb ${davinci-resolve}/bin/davinci-resolve
    '')

    ### Basic utilities
    ripgrep # better grep
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
    # video (mpv comes via programs.mpv above)
    vlc

    # music / video
    spotify

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
    crosspipe # visual audio mixer
    pamixer # cli for pulseaudio
    pavucontrol # not working!
    playerctl # MPRIS media control, used by hyprland media-key binds

    translate-shell

    # THE nvim
    inputs.danvim.packages.x86_64-linux.nvim

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

    nvidia-docker

    bluetui # Bluetooth tui

    gnome-session

    firefox
  ];

  programs.claude-code = {
    enable = true;
    # settings = {
    #   # Strip Anthropic/Claude attribution from git commits and PRs
    #   # (no "🤖 Generated with Claude Code" footer, no Co-Authored-By trailer).
    #   includeCoAuthoredBy = false;
    # };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Voxtype Home Manager configuration
  programs.voxtype = {
    enable = false;
    package = inputs.voxtype.packages.x86_64-linux.vulkan;
    model.name = "large-v3-turbo";
    service.enable = true;
    settings = {
      hotkey.enabled = false;
      whisper.language = "en";
      backend = "vulkan";
      # find the name via `pactl list sources` and look for the microphone you want to use
      device = "alsa_input.pci-0000_80_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source";
    };
  };
}
