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
    # ghostty is installed too, and noctalia's runInTerminal would otherwise
    # prefer it.
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
      # OSD only — the same chrome-vs-content line firefox/default.nix draws.
      # sub-color and friends are deliberately absent: subtitles are part of
      # what is being watched, not part of the player's UI, and recolouring
      # them would be the video equivalent of forcing a website's palette.
      #
      # The letterbox that mpv paints around a non-matching aspect ratio is
      # `background`, whose default is `tiles` (a light checkerboard); pinning
      # it to a flat palette colour is what keeps a 21:9 film from sitting in
      # a grey grid. Colors are AARRGGBB, alpha first.
      osd-color = "#FF${pal.fg}";
      osd-outline-color = "#FF${pal.bgDeep}";
      osd-back-color = "#AF${pal.bg}";
      background = "color";
      background-color = "#FF${pal.bgDeep}";

      ytdl-format = "bestvideo+bestaudio";
      keep-open = true; # Don't close mpv when video is done
      # Decode on the iGPU media block (iHD VA-API) instead of CPU cores.
      # auto-safe only picks whitelisted-stable hwdec backends.
      hwdec = "auto-safe";
      # libplacebo's default Vulkan device pick is the discrete GPU, but
      # Hyprland composites on the Intel iGPU (first in hyprland.lua's
      # AQ_DRM_DEVICES; the NVIDIA card only scans out the HDMI/DP ports
      # wired to it). Rendering on the dGPU would push every frame across
      # PCIe into the compositor. Pin to the iGPU that's actually compositing;
      # the name is Mesa's for this Arrow Lake iGPU (8086:7d67).
      vulkan-device = "Intel(R) Graphics (ARL)";
    };
  };

  # The lightweight image viewer. imv paints a checkerboard behind anything
  # with transparency or a non-matching aspect ratio by default, which is the
  # brightest thing on the screen in a dark session; `background` replaces it
  # with a flat palette colour. imv takes bare hex with no leading '#', which
  # is palette.nix's native form.
  #
  # The overlay is imv's own status line (filename, dimensions, index) — UI,
  # not image data. Nothing here touches how the image itself is decoded.
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
    ### Browsers
    # chromium and firefox are installed by their own modules (./chromium.nix,
    # ./firefox), which also carry their theming.
    nvd # Nix version diff tool
    # Lazy store of every binary nixpkgs ever shipped, scoped to a mount
    # namespace that dies with the shell (the NixOS module would replace
    # /nix/store system-wide, which is meant for VMs).
    inputs.omnibin.packages.${pkgs.stdenv.hostPlatform.system}.omnibin-shell
    inputs.omnibin.packages.${pkgs.stdenv.hostPlatform.system}.omnibin
    manix # NixOS/home-manager options search (backs `tv nix-options`)

    python3

    ### Communication
    slack
    telegram-desktop
    # Element comes via programs.element-desktop in ./element.nix.
    # services.nextcloud-client below runs the client; the package is here
    # for its launcher entry, which the service does not install.
    nextcloud-client

    # From the release branch (pkgs.stable, the overlay in configuration.nix).
    pkgs.stable.grayjay # video platform aggregator
    pkgs.stable.discord

    ### Basic utilities
    ripgrep # better grep
    # tldr comes from programs.tealdeer in ./terminal
    acpi # To meassure laptop battery levels
    brightnessctl # Control brightness via CLI
    unzip
    wget
    ffmpeg
    zip

    ### Media viewing
    # video (mpv comes via programs.mpv above)

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

    # "Open in Terminal" comes from programs.nautilus-open-any-terminal in
    # configuration.nix.
    nautilus

    android-tools

    # Process management: btop and bottom both come from ./terminal, which
    # carries their Ember themes.

    bluetui # Bluetooth tui
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Started with the graphical session, in the tray.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
