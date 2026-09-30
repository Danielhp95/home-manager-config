{
  inputs,
  pkgs,
  ...
}:

let
  # Bare hex (no leading '#'), palette.nix's native form.
  pal = import ./palette.nix;
in
{

  home.stateVersion = "24.05";

  home.sessionVariables = {
    BROWSER = "firefox";
    # noctalia's runInTerminal would otherwise pick ghostty.
    TERMINAL = "kitty";
  };

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableExtraSocket = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-curses;
  };

  # Bluetooth headset buttons control MPRIS playback.
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

    # Apps that draw their own UI, so GTK/Qt theming does not reach them.
    ./firefox
    ./chromium.nix
    ./element.nix
    ./spotify.nix

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
  ];

  programs.mpv = {
    enable = true;
    config = {
      # OSD only: subtitles are content and keep their own colours.
      # `background` is the letterbox (default: a light checkerboard).
      # Colours are AARRGGBB.
      osd-color = "#FF${pal.fg}";
      osd-outline-color = "#FF${pal.bgDeep}";
      osd-back-color = "#AF${pal.bg}";
      background = "color";
      background-color = "#FF${pal.bgDeep}";

      ytdl-format = "bestvideo+bestaudio";
      keep-open = true; # Don't close mpv when video is done
      # VA-API on the iGPU (iHD); auto-safe only uses whitelisted backends.
      hwdec = "auto-safe";
      # libplacebo defaults to the dGPU, but Hyprland composites on the iGPU
      # (AQ_DRM_DEVICES in hyprland.lua), so render there instead of copying
      # every frame across PCIe. The name is Mesa's for this iGPU.
      vulkan-device = "Intel(R) Graphics (ARL)";
    };
  };

  # A flat background instead of imv's default checkerboard, and an Ember
  # status line. imv takes bare hex, palette.nix's native form.
  programs.imv = {
    enable = true;
    settings.options = {
      background = pal.bgDeep;
      overlay_text_color = pal.fg;
      overlay_background_color = pal.bg;
      overlay_background_alpha = "e0";
    };
  };

  home.packages = with pkgs; [
    # chromium and firefox come from ./chromium.nix and ./firefox.
    nvd # Nix version diff tool
    # Any binary nixpkgs ever shipped, in a per-shell mount namespace. Not the
    # NixOS module: it replaces /nix/store system-wide (meant for VMs).
    inputs.omnibin.packages.${pkgs.stdenv.hostPlatform.system}.omnibin-shell
    inputs.omnibin.packages.${pkgs.stdenv.hostPlatform.system}.omnibin
    manix # NixOS/home-manager options search (backs `tv nix-options`)

    python3

    ### Communication
    slack
    telegram-desktop
    # Element comes from ./element.nix.
    # For the launcher entry; services.nextcloud-client below runs the client.
    nextcloud-client

    # From the release branch (pkgs.stable, the overlay in configuration.nix).
    pkgs.stable.grayjay # video platform aggregator
    pkgs.stable.discord

    ### Basic utilities
    ripgrep # better grep
    # tldr comes from programs.tealdeer in ./terminal
    acpi # Laptop battery levels
    brightnessctl # Control brightness via CLI
    unzip
    wget
    ffmpeg
    zip

    ### Media viewing
    # video (mpv comes via programs.mpv above)

    # spotify comes from ./spotify.nix; a plain pkgs.spotify would shadow it.

    # Images
    # imv comes via programs.imv above.
    gthumb # Viewer for multiple images

    # Best youtube downloader
    yt-dlp
    ###

    ### debugging utils
    # lnav comes from ./lnav (`journalctl | lnav`).
    pciutils # For `lspci` command.
    nvtopPackages.full # Better `nvidia-smi` that also supports AMD GPUs
    powertop # Analyze power consumption for intel based processors

    ### Audio
    crosspipe # visual audio mixer
    pavucontrol
    playerctl # MPRIS media control, used by hyprland media-key binds

    translate-shell

    # THE nvim
    inputs.danvim.packages.${pkgs.stdenv.hostPlatform.system}.nvim

    # Weather app
    gnome-weather

    adwaita-icon-theme # symbolic-icon fallback for GNOME apps (MoreWaita expects it)
    gparted

    # Its "Open in Terminal" entry comes from configuration.nix.
    nautilus

    android-tools

    # btop and bottom come from ./terminal.

    bluetui # Bluetooth tui
  ];

  programs.home-manager.enable = true;

  # Started with the graphical session, in the tray.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
