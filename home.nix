{
  inputs,
  stableWithUnfree,
  unstableWithUnfree,
  config,
  pkgs,
  environment,
  ...
}:

let
  nvidiaZoom = pkgs.zoom-us.override { meta.mainProgram = "nvidia-offload zoom"; };
in
{

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "24.05";

  home.sessionVariables = {
    BROWSER = "firefox";
  };

  imports = [
    ./starship
    ./zsh
    ./tmux
    ./zellij

    ./yazi

    ./zathura.nix
    ./git
    ./menu_launchers

    # Gestures
    ./fusuma

    # ./neovim
    ./terminal
    ./kitty
    ./atuin.nix

    ./hyprland
    # ./sway/waybar.nix # It will be outdated
    ./status_bars

    ./sony_ai

    # ./anyrun
    ./notifications
  ];

  khome.desktop.swww = {
    enable = true;
    wallpaperDirs = [
      "~/nix_config/wallpapers"
    ]; # TODO: create an env variable based on this and use that everywhere else
  };

  programs.firefox.enable = true;
  services.clipmenu.enable = true;

  # Why do I have this
  home.file = {
    ".nv/nvidia-application-profiles-rc".text = ''
      {
          "rules": [
              {
                  "pattern": {
                      "feature": "dso",
                      "matches": "libGL.so.1"
                  },
                  "profile": "openGL_fix"
              }
          ],
          "profiles": [
              {
                  "name": "openGL_fix",
                  "settings": [
                      {
                          "key": "GLThreadedOptimizations",
                          "value": false
                      }
                  ]
              }
          ]
      }
    '';
  };

  home.packages = with pkgs; [
    ### Browsers
    chromium
    nvd # Nix version diff tool
    nushell

    ### Style
    pywal # Colorscheme generator

    ### Communication
    slack
    telegram-desktop
    element-desktop
    stableWithUnfree.zoom-us

    openconnect

    ### Photography
    ansel

    ### Videography
    (writeScriptBin "davinci" ''
      QT_QPA_PLATFORM=xcb ${unstableWithUnfree.davinci-resolve}/bin/davinci-resolve
    '')

    # Latex stuff
    pandoc

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
    # music
    unstableWithUnfree.spotify
    # Images
    imv

    texlive.combined.scheme-full

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

    xfce.thunar

    inputs.danvim.packages.x86_64-linux.nvimStable

    # Weather app
    mousam

    # Best youtube downloader
    yt-dlp

    obsidian

    # Audio recording
    asak

    gparted
    bottom

    # nix cli helper, useful for switching etc
    nh
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
