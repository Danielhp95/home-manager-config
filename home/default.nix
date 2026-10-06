{
  pkgs,
  theme,
  ...
}:

let
  # Bare hex (no leading '#'), the palette's native form.
  pal = theme;
  inherit (theme.colour) argb;
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
    ./vicinae

    # Apps that draw their own UI, so GTK/Qt theming does not reach them.
    ./firefox
    ./chromium.nix
    ./element.nix
    ./spotify.nix

    ./lnav

    ./terminal

    ./claude-code
    ./kitty
    ./ghostty
    ./ipython
    ./matplotlib.nix

    ./hyprland
    ./noctalia

    ./sony-ai.nix

    ./writing.nix
    ./default-applications.nix
  ];

  programs.mpv = {
    enable = true;
    config = {
      # OSD only: subtitles are content and keep their own colours.
      # `background` is the letterbox (default: a light checkerboard).
      # Colours are AARRGGBB (colour.argb).
      osd-color = argb "FF" pal.fg;
      osd-outline-color = argb "FF" pal.bgDeep;
      osd-back-color = argb "AF" pal.bg;
      background = "color";
      background-color = argb "FF" pal.bgDeep;

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
  # status line. imv takes bare hex, the palette's native form.
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
    nvd # Nix version diff tool
    # Any binary nixpkgs ever shipped, in a per-shell mount namespace. Not the
    # NixOS module: it replaces /nix/store system-wide (meant for VMs).
    omnibin-shell
    omnibin
    manix # NixOS/home-manager options search (backs `tv nix-options`)

    python3

    ### Communication
    slack
    telegram-desktop
    # For the launcher entry; services.nextcloud-client below runs the client.
    nextcloud-client

    # Unstable as of this date, not pkgs.stable: an app on an older glibc than
    # the system's cannot load its Mesa, renders on the dGPU instead, and its
    # NVIDIA buffers abort Hyprland. Move the date along with nixpkgs.
    (pkgs.multiverse.at "2026-10-02").grayjay # video platform aggregator
    # From the release branch (pkgs.stable, pkgs/overlay.nix).
    pkgs.stable.discord

    ### Basic utilities
    ripgrep # better grep
    acpi # Laptop battery levels
    brightnessctl # Control brightness via CLI
    unzip
    wget
    ffmpeg
    zip

    ### Media viewing
    # spotify comes from ./spotify.nix; a plain pkgs.spotify would shadow it.

    gthumb # Viewer for multiple images
    yt-dlp

    ### debugging utils
    pciutils # For `lspci` command.
    nvtopPackages.full # Better `nvidia-smi` that also supports AMD GPUs
    powertop # Analyze power consumption for intel based processors

    ### Audio
    crosspipe # visual audio mixer
    pavucontrol
    playerctl # MPRIS media control, used by hyprland media-key binds

    translate-shell

    pkgs.danvim # nvim, with the selected palette (pkgs/danvim.nix)
    gnome-weather

    adwaita-icon-theme # symbolic-icon fallback for GNOME apps (MoreWaita expects it)
    gparted

    # Its "Open in Terminal" entry comes from nixos/default.nix.
    nautilus

    android-tools

    bluetui # Bluetooth tui
  ];

  programs.home-manager.enable = true;

  # Started with the graphical session, in the tray.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
