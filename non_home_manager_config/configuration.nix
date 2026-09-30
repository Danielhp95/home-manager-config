{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.default
    ../claude_code/managed-settings.nix
    ../pipewire.nix
    ./network.nix
    ./tailscale.nix
    ./ollama.nix
    ./noctalia-greeter.nix
    ./esp-check.nix
    ./grub-generation-label.nix
    ./fonts.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
    inputs.firefox-addons.overlays.default # pkgs.firefox-addons.*
    (
      final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        hyprland = inputs.hyprland.packages.${system}.hyprland;
      in
      {
        inherit (inputs.iris.packages.${system}) iris;
        # hy3 links against Hyprland's headers, so it must get the exact
        # Hyprland build that is installed.
        inherit hyprland;
        hy3 = inputs.hy3.packages.${system}.hy3.override { inherit hyprland; };
        inherit (inputs.hyprland.packages.${system}) xdg-desktop-portal-hyprland;
        # Without mbrola: its voices are ~645 MB and nothing here uses them.
        espeak-ng = prev.espeak-ng.override { mbrolaSupport = false; };
        # The release branch, for packages pinned to it (pkgs.stable.<name>).
        stable = import inputs.stable {
          inherit (final.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      }
    )
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.dani = ../home.nix;
    # Apps replace some managed files with real ones (mimeapps.list, GTK
    # settings); HM moves those aside, and a .backup left by an earlier
    # activation would otherwise abort the next one.
    backupFileExtension = "backup";
    overwriteBackup = true;
  };

  programs.ydotool.enable = true;

  # Backend for the noctalia/screen_recorder plugin (Super+Shift+R). The NixOS
  # module adds the setcap'd gsr-kms-server wrapper it needs for KMS capture.
  programs.gpu-screen-recorder.enable = true;

  programs.steam.enable = true;

  # Nautilus' "Open in Terminal" context entry, opening kitty.
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  # Installs LocalSend and opens its port (53317, TCP + UDP) for receiving.
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # Authenticator manager
  security.polkit.enable = true;

  nix = {
    settings = {
      extra-experimental-features = [
        "flakes"
        "nix-command"
      ];
      # This flake's working tree is dirty nearly always, so the "Git tree is
      # dirty" line on every `nh os switch` / `nix fmt` carried no information.
      warn-dirty = false;
      substituters = [
        # cache.nixos.org builds no CUDA; this serves ollama-cuda and its libs.
        # (Replaces cuda-maintainers.cachix.org, gone since 2025-11.)
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
    # `nixpkgs#` already resolves to the pinned nixpkgs; these add the short
    # `nixos#` alias for it and `stable#` for the release branch.
    registry = {
      nixos.flake = inputs.nixpkgs;
      stable.flake = inputs.stable;
    };
    optimise.automatic = true; # periodically run `nix store optimise`
    # Garbage collection is handled by `programs.nh.clean` below (the NixOS nh
    # module asserts that nix.gc.automatic and nh.clean must not both be on).

    # Keep 24-core rebuilds from competing with the desktop: build processes
    # yield CPU to interactive work and only use idle disk bandwidth.
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };

  # nh: ergonomic `nixos-rebuild` frontend. `nh os switch` builds with
  # nix-output-monitor output and a generation diff; `nh clean` replaces nix.gc.
  programs.nh = {
    enable = true;
    flake = "/home/dani/nix_config";
    clean = {
      enable = true;
      # 15d/5 was retaining ~57 generations (~83 GB of store), and even 7d kept
      # ~60 around with frequent switching on a 91%-full disk. Three days of
      # rollback targets plus the last 10 generations is plenty in practice.
      # Age-based on purpose, same reasoning as the classic
      # `nix.gc.options = "--delete-older-than 30d"`: a blanket `-d`/
      # `--delete-old` is what stripped the running kernel's modules out from
      # under it after a rebuild silently failed to reach the ESP.
      # `--keep` never drops below boot.loader.grub.configurationLimit (the
      # hardware file): GC must never delete a generation GRUB still lists.
      extraArgs = "--keep-since 3d --keep ${toString (lib.max 10 config.boot.loader.grub.configurationLimit)}";
    };
  };

  # kexec-tools on PATH. NixOS's kexec module enables this by default, but it
  # is what made the 2026-09 recovery possible without a USB stick (booting
  # the matching kernel straight from the store after a wrong-kernel boot),
  # so it is pinned here rather than left to an upstream default.
  boot.kexec.enable = true;

  # Compressed in-RAM swap. The machine had no swap at all: systemd-oomd
  # degraded to pressure-only mode and nix-daemon died with SIGABRT during
  # large rebuilds (30G+ peak on 2026-08-02).
  zramSwap.enable = true;

  # BBR keeps throughput up on lossy/high-latency paths where cubic backs
  # off hard (substitution downloads, video calls on hotel wifi). fq is the
  # pacing-aware qdisc BBR wants.
  boot.kernelModules = [ "tcp_bbr" ];

  # Tune the VM for zram being the only swap. Mostly matters under the
  # memory pressure of large rebuilds (the SIGABRT scenario above).
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    # Swap-in readahead is free on disk but pure waste on zram: decompressing
    # 8 pages to service a 1-page fault. 0 = fault exactly what's needed.
    "vm.page-cluster" = 0;
    # Swapping to zram is nearly free compared to dropping page cache that
    # must be re-read from disk; 180 is the upstream zram recommendation.
    "vm.swappiness" = 180;
    # Watermark boosting defends against fragmentation by reclaiming early —
    # counterproductive here: it starts swapping under mild pressure.
    "vm.watermark_boost_factor" = 0;
  };

  # TLP replaces power-profiles-daemon (the two conflict; the NixOS module
  # asserts they're not both enabled). TLP applies the *_ON_AC settings when
  # plugged in and *_ON_BAT when on battery automatically on plug/unplug.
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
    # There is no swap device (only zram), so Hibernate has nowhere to write the
    # image: the action fails and the battery drains to a hard power loss.
    # PowerOff is the only action here that can't lose the filesystem state.
    criticalPowerAction = "PowerOff";
  };

  programs.dconf.enable = true;
  programs.nix-ld.enable = true;

  xdg.portal = {
    enable = true; # home-manager's portal module asserts on the pathsToLink this sets
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # FileChooser/Settings fallback ("hyprland;gtk")
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # The terminals' ANSI 0-15, so the LUKS prompt and ttys are Ember.
  # Set via kernel params: takes effect on the next boot.
  console.colors = (import ../palette.nix).ansi;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # From https://wiki.nixos.org/wiki/Locales
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "C.UTF-8/UTF-8" # What is this
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

  # The greeter's Hyprland session execs `start-hyprland` directly
  # (Hyprland's own crash-watchdog binary, noctalia-greeter.nix), and session
  # lifecycle goes through home-manager's own systemd integration instead
  # (wayland.windowManager.hyprland.systemd, hyprland/default.nix):
  #
  #   greeter session script (exports fcitx/wayland env, then sources
  #   home.sessionVariables from hm-session-vars.sh)
  #     -> start-hyprland execs Hyprland, restarts it if it dies non-cleanly
  #     -> hyprland.start hook: dbus-update-activation-environment --systemd
  #        --all, then stop/start hyprland-session.target
  #     -> graphical-session.target goes active; every service WantedBy
  #        it (fcitx5-daemon, hyprpolkitagent, vicinae, noctalia,
  #        gpg-agent.socket...) starts with the wayland env guaranteed.
  #   Compositor exit stops hyprland-session.target and everything bound to it.
  #
  # Gotchas:
  #   - Session daemons must be systemd units WantedBy=graphical-session.
  #     target. exec-once / manual `systemctl start` in the startup path
  #     killed the polkit agent and gpg-agent silently before this was
  #     fixed — see graphical-session-target-dance memory.
  #   - Never override wayland.windowManager.hyprland.systemd.extraCommands
  #     to stop graphical-session.target directly — that's the exact
  #     hand-rolled hook that caused the above. Leave it at the module
  #     default (stop/start hyprland-session.target, one level down).

  # Services a GNOME desktop would normally enable
  services.gvfs.enable = true; # yazi/nautilus: MTP, network shares (see yazi/default.nix)
  services.udisks2.enable = true; # yazi mount menu
  services.gnome.gnome-keyring.enable = true; # Secret Service for apps; unlocked at login via greetd's PAM stack (substacks login)
  services.gnome.glib-networking.enable = true; # TLS for libsoup (GNOME apps such as gnome-weather)
  services.geoclue2.enable = true; # maps/weather location; demo agent replaces gnome-shell's
  services.gnome.at-spi2-core.enable = true; # a11y bus; silences GTK warnings

  services.xserver = {
    # Enable the X11 windowing system.
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
  ]; # Make sure that home-manager installed `zsh` picks up system installed programs

  programs.zsh.enable = true;
  # Home-manager runs compinit with the full fpath (plugins included); running
  # it here too makes the two fight over ~/.config/zsh/.zcompdump, rebuilding
  # it twice on every shell launch (~1s of terminal startup time).
  programs.zsh.enableCompletion = false;
  users.users.dani = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "ydotool" # access to the ydotoold socket (keyboard-driven scrolling)
    ]; # group "wheel" -> sudo access
    hashedPassword = "$y$j9T$BS53tFZ/aYhulnHaIPdfV1$RgynhBpss3Mkz6Rliz3nn4KsTaQ9RI1mdB8qLb5OdxC";
  };

  # system.stateVersion is per machine: it lives in the hardware file
  # (hardwares/lenovo_t16g_gen3.nix).
}
