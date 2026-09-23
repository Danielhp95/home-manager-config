{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  pal = (import ./palette.nix).hash;
in
{

  home.stateVersion = "24.05";

  home.sessionVariables = {
    BROWSER = "firefox";
  };

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

  # To allow bluetooth devices buttons to control media things (like stop / play)
  services.mpris-proxy.enable = true;

  imports = [
    ./fcitx5

    ./starship
    ./zsh
    ./tmux

    ./yazi

    ./zathura.nix
    ./git
    ./menu_launchers

    # Apps that draw their own UI and so need theming of their own, rather
    # than picking up WhiteSur-Dark-orange from GTK/Qt.
    ./firefox
    ./chromium.nix
    ./element.nix
    ./spotify.nix

    ./easyeffects.nix
    ./pipewire-eq.nix

    ./lnav

    ./terminal
    ./terminal/television.nix
    ./terminal/nushell.nix
    ./terminal/iris.nix

    ./claude_code
    ./kitty
    ./ghostty
    ./ipython

    ./hyprland
    ./noctalia

    ./sony_ai

    ./writing.nix
    ./default_applications.nix
    # Import voxtype HM module
    inputs.voxtype.homeManagerModules.default
  ];

  programs.mpv = {
    enable = true;
    config = {
      # OSD only — the same chrome-vs-content line firefox/default.nix draws.
      # sub-color and friends are deliberately absent: subtitles are part of
      # what is being watched, not part of the player's UI, and recolouring
      # them would be the video equivalent of forcing a website's palette.
      #
      # The letterbox that mpv paints around a non-matching aspect ratio is
      # `background`, whose default is `tiles` (a light checkerboard); pinning
      # it to a flat palette colour is what keeps a 21:9 film from sitting in
      # a grey grid. Colors are AARRGGBB, alpha first.
      osd-color = "#FF${builtins.substring 1 6 pal.fg}";
      osd-outline-color = "#FF${builtins.substring 1 6 pal.bgDeep}";
      osd-back-color = "#AF${builtins.substring 1 6 pal.bg}";
      background = "color";
      background-color = "#FF${builtins.substring 1 6 pal.bgDeep}";

      ytdl-format = "bestvideo+bestaudio";
      keep-open = true; # Don't close mpv when video is done
      # Decode on the iGPU media block (iHD VA-API) instead of CPU cores.
      # auto-safe only picks whitelisted-stable hwdec backends.
      hwdec = "auto-safe";
      # libplacebo's default Vulkan device pick is the discrete GPU, but on
      # this PRIME-offload laptop only the Intel iGPU drives the physical
      # displays. Rendering on the nvidia dGPU meant every frame crossed
      # PCIe into the compositor (stutter/tearing) and device creation on
      # the dGPU cold-started in >1s ("(slow!)" in -v output). Pin to the
      # iGPU that's actually compositing.
      vulkan-device = "Intel(R) Graphics (ARL)";
    };
  };

  # The lightweight image viewer. imv paints a checkerboard behind anything
  # with transparency or a non-matching aspect ratio by default, which is the
  # brightest thing on the screen in a dark session; `background` replaces it
  # with a flat palette colour. imv takes bare hex with no leading '#', unlike
  # every other consumer of palette.nix, hence the substring.
  #
  # The overlay is imv's own status line (filename, dimensions, index) — UI,
  # not image data. Nothing here touches how the image itself is decoded.
  programs.imv = {
    enable = true;
    settings.options = {
      background = builtins.substring 1 6 pal.bgDeep;
      overlay_text_color = builtins.substring 1 6 pal.fg;
      overlay_background_color = builtins.substring 1 6 pal.bg;
      overlay_background_alpha = "e0";
    };
  };

  home.packages = with pkgs; [
    ### Browsers
    # chromium and firefox are installed by their own modules (./chromium.nix,
    # ./firefox), which also carry their theming.
    nvd # Nix version diff tool
    manix # NixOS/home-manager options search (backs `tv nix-options`)

    python3

    ### Communication
    slack
    telegram-desktop
    element-desktop
    nextcloud-client

    # zoom-us

    (
      (inputs.multiverse.lib.mkMultiverse {
        system = "x86_64-linux";
        config.allowUnfree = true;
      }).at
      "26.05"
    ).grayjay # video platform aggregator
    (
      (inputs.multiverse.lib.mkMultiverse {
        system = "x86_64-linux";
        config.allowUnfree = true;
      }).at
      "26.05"
    ).discord # video platform aggregator

    openconnect

    ## Videography
    (writeScriptBin "davinci" ''
      QT_QPA_PLATFORM=xcb ${
        (
          (inputs.multiverse.lib.mkMultiverse {
            system = "x86_64-linux";
            config.allowUnfree = true;
          }).at
          "26.05"
        ).davinci-resolve
      }/bin/davinci-resolve
    '')

    ### Basic utilities
    ripgrep # better grep
    zenith # better top
    # tldr comes from programs.tealdeer in ./terminal
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
    # spotify comes from ./spotify.nix (spicetify-wrapped); installing
    # pkgs.spotify as well would shadow it.

    # Images
    # imv comes via programs.imv below, which carries its Ember colors.
    gthumb # Viewer for multiple images

    # Best youtube downloader
    yt-dlp
    ###

    ### debugging utils
    # lnav comes via ./lnav, which carries its Ember theme. Use it to pipe
    # `journalctl | lnav` for syntax highlighting / filtering.
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
    gnome-weather

    gnome-calendar
    adwaita-icon-theme # symbolic-icon fallback for GNOME apps (MoreWaita expects it)
    gparted
    decibels # audio playing with nice waveform graphics

    nautilus
    nautilus-open-any-terminal
    lingot # Instrument tuner

    android-tools

    # Process management: btop and bottom both come from ./terminal, which
    # carries their Ember themes.

    # File sharing (Like AirDrop)
    localsend

    bluetui # Bluetooth tui
  ];

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
