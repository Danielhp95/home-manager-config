# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../tuigreet.nix
    ../fcitx5/fonts.nix # the input method itself is home-manager config now
    ./voxtype.nix
  ];

  programs.ydotool.enable = true;

  # Move to gaming folder
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;

  # Authenticator manager
  security.polkit.enable = true;

  nix = {
    settings.extra-experimental-features = [
      "flakes"
      "nix-command"
    ];
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
      extraArgs = "--keep-since 3d --keep 10";
    };
  };

  # gcr provides the D-Bus prompter that gnome-keyring and gcr-ssh-agent use
  # for unlock/PIN dialogs; without it keyring prompts silently fail.
  services.dbus.packages = [ pkgs.gcr ];

  # Compressed in-RAM swap. The machine had no swap at all: systemd-oomd
  # degraded to pressure-only mode and nix-daemon died with SIGABRT during
  # large rebuilds (30G+ peak on 2026-08-02).
  zramSwap.enable = true;

  # The journal had grown to 3.9 GB with no cap on a 91%-full disk.
  services.journald.extraConfig = "SystemMaxUse=500M";

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
  # Intel thermal management: keeps the CPU in efficient thermal envelopes.
  services.thermald.enable = true;

  # Let the tlp-mode bar widget force/unforce battery mode without a password.
  security.sudo.extraRules = [
    {
      users = [ "dani" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/tlp";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/tlp-stat";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    percentageAction = 5;
    # There is no swap device (only zram), so Hibernate has nowhere to write the
    # image: the action fails and the battery drains to a hard power loss.
    # PowerOff is the only action here that can't lose the filesystem state.
    criticalPowerAction = "PowerOff";
  };

  # To get PS5 controller working in proton
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "70-ps5-controller.rules";
      text = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
        KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0660", TAG+="uaccess"
      '';
      destination = "/etc/udev/rules.d/70-ps5-controller.rules";
    })
  ];

  programs.dconf.enable = true;
  programs.nix-ld.enable = true;

  # Enables docker
  # From https://nixos.wiki/wiki/Nvidia
  # Warning keeps telling me to:
  virtualisation.docker = {
    enable = true;
    # Socket activation instead of boot start: docker.service and the CDI
    # generator below were ~4.8s of the chain greetd waits behind. The first
    # `docker` command after boot pays that cost instead.
    enableOnBoot = false;
    daemon.settings = {
      features.cdi = true;
      # Clean up on restart
      live-restore = false; # Don't try to restore containers on restart
    };
    # Auto-prune old containers
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };
  hardware.nvidia-container-toolkit.enable = true;
  # The CDI generator probes the dGPU (waking it from D3cold) and sat on the
  # boot critical chain via multi-user.target. Tie it to docker's actual
  # start instead: it still always runs before dockerd needs the CDI spec.
  systemd.services.nvidia-container-toolkit-cdi-generator = {
    wantedBy = lib.mkForce [ ];
    requiredBy = [ "docker.service" ];
    before = [ "docker.service" ];
  };

  xdg.portal = {
    enable = true; # home-manager's portal module asserts on the pathsToLink this sets
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # FileChooser/Settings fallback ("hyprland;gtk")
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  khome = {
    tuigreet = {
      enable = true;
      enableWaylandEnvs = true;
      defaultSession = "hyprland";
      # Sans pixel art (plain half-blocks, colored by the theme's `greet`)
      greetingFile = ../tuigreet_theme/sans.txt;
      sessions = {
        hyprland.enable = true;
        zsh.enable = true; # drop-to-tty login shell on the greeter's VT
      };
    };
  };

  fonts.packages = with pkgs; [
    # Noto: means no tofu. Tofu is the colloquial term for errors in rendering chinese characters
    noto-fonts
    babelstone-han # unicode font with loooads of Han characters

    font-awesome # NOTE do I need this?
    material-symbols

    fira-code-symbols # NOTE might not be needed with nord-fonts.firacode
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    # NOTE nerd-fonts.iosevka was dropped: ~1 GB of closure (it ships ~100 style
    # variants) for two uses. Its consumers now point elsewhere — vicinae at
    # ../menu_launchers/default.nix uses JetBrainsMono NF, and the media-control
    # symbol_map in ../kitty/kitty.conf uses Noto Sans Symbols 2 + Unifont.
    nerd-fonts.symbols-only # full "Symbols Nerd Font Mono" — complete icon set, used as kitty fallback
  ];

  # Set your time zone.
  # services.automatic-timezoned.enable = true;
  # For manual timezones
  time.timeZone = "America/New_York";
  # time.timeZone = "Europe/Madrid";

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

  # Universal Wayland Session Manager. tuigreet's hyprland session runs
  # `uwsm start -- Hyprland` (tuigreet.nix), which turns the session into
  # systemd user units instead of a hand-managed process tree:
  #
  #   greetd session script (exports fcitx/wayland env)
  #     -> uwsm start: pushes that env into the user manager + dbus,
  #        then starts wayland-wm@Hyprland.service (Type=notify)
  #     -> Hyprland runs `uwsm finalize` (hyprland.lua start hook):
  #        exports WAYLAND_DISPLAY etc. and signals readiness
  #     -> graphical-session.target goes active; every service WantedBy
  #        it (fcitx5-daemon, hyprpolkitagent, vicinae, noctalia, awww,
  #        gpg-agent.socket...) starts with the wayland env guaranteed.
  #   Compositor exit stops the target and everything bound to it.
  #
  # Day-to-day:
  #   - session health:  systemctl --user status wayland-wm@Hyprland
  #   - session log:     journalctl --user -u wayland-wm@Hyprland
  #   - graceful logout: `uwsm stop` (plain `hyprctl dispatch exit` also
  #     works — uwsm notices the compositor died — but stop is the
  #     intended path and what a power-menu logout should call)
  #   - optional: launch GUI apps as `uwsm app -- <cmd>` to give each its
  #     own scope (a crashing app can't drag the compositor cgroup down)
  #
  # Gotchas:
  #   - `uwsm finalize` in hyprland.lua is load-bearing: wayland-wm@ is
  #     Type=notify, so if the hook is removed the session times out and
  #     gets torn down (~10s of Hyprland, then back to tuigreet).
  #   - Session daemons must be systemd units WantedBy=graphical-session.
  #     target. exec-once / manual `systemctl start` in the startup path
  #     is how the polkit agent and gpg-agent silently died pre-uwsm.
  #   - Keep home-manager's wayland.windowManager.hyprland.systemd.enable
  #     = false (hyprland/default.nix): its generated hook stops/starts
  #     graphical-session.target by hand and would fight uwsm.
  #   - uwsm activates xdg-desktop-autostart.target, which the old setup
  #     never did: /etc/xdg/autostart entries now run (keyring + at-spi
  #     are idempotent, geoclue agent + evolution-alarm-notify are
  #     wanted, iwgtk-indicator is new). Audit with
  #     `systemctl --user list-units 'app-*'`.
  #   - The service environment is a login-time snapshot (greetd exports
  #     + finalize vars). Exporting vars in a shell later never reaches
  #     services; change tuigreet.nix / hyprland.lua instead.
  #   - One graphical session per user: uwsm start refuses a second one.
  programs.uwsm.enable = true;

  # Services previously pulled in implicitly by services.desktopManager.gnome
  services.gvfs.enable = true; # yazi/nautilus: MTP, network shares (see yazi/default.nix)
  services.udisks2.enable = true; # yazi mount menu
  services.gnome.evolution-data-server.enable = true; # gnome-calendar storage daemons (no mail client pulled in)
  services.gnome.gnome-online-accounts.enable = true; # online calendars
  services.gnome.gnome-keyring.enable = true; # GOA/EDS secrets; PAM unlock wired in tuigreet.nix
  services.gnome.glib-networking.enable = true; # TLS for libsoup: map tiles, OAuth, https calendars
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

  # Commented out because we are not using X
  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
      "docker"
      "ydotool" # access to the ydotoold socket (keyboard-driven scrolling)
    ]; # group "wheel" -> sudo access
    packages = [ ];
    hashedPassword = "$y$j9T$BS53tFZ/aYhulnHaIPdfV1$RgynhBpss3Mkz6Rliz3nn4KsTaQ9RI1mdB8qLb5OdxC";
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
