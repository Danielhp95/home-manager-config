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
    ../fcitx5
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
  };

  # nh: ergonomic `nixos-rebuild` frontend. `nh os switch` builds with
  # nix-output-monitor output and a generation diff; `nh clean` replaces nix.gc.
  programs.nh = {
    enable = true;
    flake = "/home/dani/nix_config";
    clean = {
      enable = true;
      extraArgs = "--keep-since 15d --keep 5";
    };
  };

  services.dbus.packages = [ pkgs.gcr ]; # Why do I want this?

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
    criticalPowerAction = "Hibernate";
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

  xdg.portal.configPackages = with pkgs; [
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gnome # For the GNOME session
  ];

  khome = {
    tuigreet = {
      enable = true;
      enableWaylandEnvs = true;
      # Pre-select hyprland instead of the alphabetical first session (gdm)
      defaultSession = "hyprland";
      sessions = {
        hyprland.enable = true;
        gdm.enable = true;
        zsh.enable = true; # Doesn't work!
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
    nerd-fonts.iosevka
    nerd-fonts.symbols-only # full "Symbols Nerd Font Mono" — complete icon set, used as kitty fallback
  ];

  # Set your time zone.
  # services.automatic-timezoned.enable = true;
  # For manual timezones
  # time.timeZone = "America/New_York";
  time.timeZone = "Europe/Madrid";

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

  # Enable / Disable the GNOME Desktop Environment.
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  services.xserver = {
    # Enable the X11 windowing system.
    enable = true;
    excludePackages = [ pkgs.xterm ];
    # TODO: remove these two, as gnome leaves breadcrumbs of programs around!
    # Figure out how to get these features without gnome

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
