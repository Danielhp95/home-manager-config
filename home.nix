{ inputs, config, pkgs, environment, ... }:

let
  nvidiaZoom = pkgs.zoom-us.override {
    meta.mainProgram = "nvidia-offload zoom";
  }; 
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

    ./zathura.nix
    ./git
    ./menu_launchers

    # Gestures
    # ./fusuma

    ./neovim
    ./terminal
    ./kitty
    ./atuin.nix

    ./hyprland
    # ./sway  # It will be outdated

    ./sony_ai

    ./ags
    # ./anyrun
    ./notifications  # TODO: remove
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
    ### Browsers
    chromium

    nvd  # Nix version diff tool
    nushell

    ### Style
    pywal # Colorscheme generator

    ### Communication
    slack
    telegram-desktop
    element-desktop
    zoom-us

    ### Photography
    # ansel

    ### Videography
    (buildFHSEnv {
      name = "davinci-resolve";
      targetPkgs = pkgs: (with pkgs; [ davinci-resolve ]);
      runScript = "davinci-resolve";
    }) # does not work :(

    ### Gaming
    steam
    gamescope  # micro compositor by steam

    # Latex stuff
    pandoc

    ### Basic utilities
    ripgrep # better grep
    bat # Better cat
    ranger # File manager
    zenith # better top
    tldr   # succint command explanations
    acpi  # To meassure laptop battery levels
    brightnessctl # Control brightness via CLI
    coreutils
    gzip
    gawk
    gnugrep
    unzip
    wget
    ffmpeg

    ### Media viewing
    # video
    vlc
    mpv
    # music
    spotify
    # Images
    imv

    ### debugging utils
    lnav  # Use it to pipe `journalctl | lnav` for syntax highlighing / filtering
    pciutils  # For `lspci` command.
    lshw  # list hardware. For instance `lshw -c display` shows all graphics cards
    nvtopPackages.full  # Better `nvidia-smi` that also supports AMD GPUs
    powertop  # Analyze power consumption for intel based processors

    ### Audio
    helvum  # visual audio mixer
    pamixer  # cli for pulseaudio
    pavucontrol  # not working!

    translate-shell

    ### VPN
    openconnect
    # libinput
    # libinput-gestures
    # wmctrl
    # ydotool

    # Authentication protocol
    kdePackages.polkit-kde-agent-1
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
