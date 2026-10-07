{
  config,
  pkgs,
  lib,
  inputs,
  theme,
  host,
  ...
}:

let
  # The one account. greeter.nix reads it back from home-manager.users.
  user = "dani";
  # This checkout, which `nh` rebuilds from.
  flakeDir = "${config.users.users.${user}.home}/nix_config";
in
{
  imports = [
    inputs.home-manager.nixosModules.default
    ./claude-code.nix
    ./audio.nix
    ./bluetooth.nix
    ./network.nix
    ./tailscale.nix
    ./ollama.nix
    ./greeter.nix
    ./esp-check.nix
    ./grub-generation-label.nix
    ./fontconfig.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
    inputs.firefox-addons.overlays.default # pkgs.firefox-addons.*
    (import ../pkgs/overlay.nix { inherit inputs theme; })
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs theme host; };
    users.${user} = ../home;
    # Apps overwrite some managed files (mimeapps.list, GTK settings); a stale
    # .backup from an earlier activation would otherwise abort the next one.
    backupFileExtension = "backup";
    overwriteBackup = true;
  };

  programs.ydotool.enable = true;

  # Backend for noctalia's screen_recorder plugin; the module adds the
  # setcap'd gsr-kms-server wrapper that KMS capture needs.
  programs.gpu-screen-recorder.enable = true;

  programs.steam.enable = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  # openFirewall: 53317 TCP + UDP, for receiving.
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  security.polkit.enable = true;

  nix = {
    settings = {
      extra-experimental-features = [
        "flakes"
        "nix-command"
      ];
      # The working tree is nearly always dirty; the warning carries no signal.
      warn-dirty = false;
      substituters = [
        # cache.nixos.org builds no CUDA; this serves ollama-cuda and its libs.
        "https://cache.nixos-cuda.org"
        # neovim-nightly-overlay builds (danvim) and other nix-community projects.
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      download-buffer-size = 268435456; # 256 MiB
      http-connections = 50;
    };
    # `nixpkgs#` is already pinned; add `nixos#` (alias) and `stable#`.
    registry = {
      nixos.flake = inputs.nixpkgs;
      stable.flake = inputs.stable;
    };
    optimise.automatic = true;
    # No nix.gc: programs.nh.clean below does GC (nh asserts only one is on).

    # Builds yield CPU and disk bandwidth to interactive work.
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };

  programs.nh = {
    enable = true;
    flake = flakeDir;
    clean = {
      enable = true;
      # Not `--delete-old`: after a rebuild that silently missed the ESP it
      # deletes the running kernel's modules. `--keep` >= GRUB's
      # configurationLimit, so GC never removes a generation GRUB lists.
      extraArgs = "--keep-since 3d --keep ${toString (lib.max 10 config.boot.loader.grub.configurationLimit)}";
    };
  };

  # On by default upstream; pinned because it can boot a kernel straight from
  # the store when the one on the ESP is wrong (recovery without a USB stick).
  boot.kexec.enable = true;

  # Compressed in-RAM swap; its higher priority puts it ahead of the LUKS swap.
  zramSwap.enable = true;

  # BBR keeps throughput on lossy/high-latency links; fq is the qdisc it wants.
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    # No swap-in readahead: on zram it decompresses 8 pages per 1-page fault.
    "vm.page-cluster" = 0;
    # Usual for zram: swapping to it beats re-reading dropped page cache.
    "vm.swappiness" = 180;
    # Boosting reclaims early (anti-fragmentation), i.e. swaps under mild load.
    "vm.watermark_boost_factor" = 0;
  };

  # TLP instead of power-profiles-daemon (they conflict).
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # Plugged in: full performance
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;

      # On battery: low power
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      CPU_BOOST_ON_BAT = 0;
      PCIE_ASPM_ON_BAT = "powersupersave";
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
    };
  };

  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    # noctalia's last battery warning fires at 2%; any higher pre-empts it.
    percentageAction = 2;
    # Not Hibernate: the 8.8 GB swap partition can't hold a 64 GB RAM image,
    # and no resume device is set.
    criticalPowerAction = "PowerOff";
  };

  programs.dconf.enable = true;
  programs.nix-ld.enable = true;

  xdg.portal = {
    enable = true; # home-manager's portal module asserts on the pathsToLink this sets
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk # Settings and the rest ("hyprland;gtk")
      pkgs.xdg-desktop-portal-termfilechooser # file dialogs: yazi (home/yazi/default.nix)
    ];
    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  # The terminals' ANSI 0-15, so the LUKS prompt and ttys are Ember.
  # Set via kernel params: takes effect on the next boot.
  console.colors = theme.ansi;

  time.timeZone = "America/New_York";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "en_GB.UTF-8/UTF-8"
      "es_ES.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "es_ES.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };

  # Session start: greeter script (./greeter.nix) -> start-hyprland;
  # Hyprland's start hook pushes the env to systemd (home/hyprland/default.nix).
  # Session daemons must be units WantedBy=graphical-session.target, never
  # exec-once; leave hyprland.systemd.extraCommands at the module default.

  # Services a GNOME desktop would normally enable
  services.gvfs.enable = true; # yazi/nautilus: MTP, network shares (see home/yazi/default.nix)
  services.udisks2.enable = true; # yazi mount menu
  services.gnome.gnome-keyring.enable = true; # Secret Service; unlocked at login by greetd's PAM stack
  services.gnome.glib-networking.enable = true; # TLS for libsoup (GNOME apps such as gnome-weather)
  services.geoclue2.enable = true; # maps/weather location; demo agent replaces gnome-shell's
  services.gnome.at-spi2-core.enable = true; # a11y bus; silences GTK warnings

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];

    desktopManager.runXdgAutostartIfNone = true;
    desktopManager.session = [
      {
        manage = "window";
        name = "Hyprland";
        start = "Hyprland";
      }
    ];
  };

  environment.pathsToLink = [
    "/share/zsh"
  ]; # completions of system packages, for Home Manager's zsh

  programs.zsh.enable = true;
  # Home Manager's zsh already runs compinit (with the plugin fpath); a second
  # run here rebuilds ~/.config/zsh/.zcompdump on every shell launch (~1s).
  programs.zsh.enableCompletion = false;
  # LS_COLORS is the palette's (home/terminal/ls-colors.nix); this would replace it
  # with the dircolors default in every interactive shell.
  programs.zsh.enableLsColors = false;
  users.users.${user} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "ydotool" # access to the ydotoold socket (keyboard-driven scrolling)
    ];
    hashedPassword = "$y$j9T$BS53tFZ/aYhulnHaIPdfV1$RgynhBpss3Mkz6Rliz3nn4KsTaQ9RI1mdB8qLb5OdxC";
  };

  # system.stateVersion is per machine: it lives in the hardware file.
}
