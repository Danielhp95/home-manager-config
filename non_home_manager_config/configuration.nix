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
  ];

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
    gc = {
      automatic = true;
      randomizedDelaySec = "14m"; # What does this do?
      options = "--delete-older-than 15d";
    };
  };

  services.dbus.packages = [ pkgs.gcr ]; # Why do I want this?

  services.power-profiles-daemon.enable = true;

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

  # Enables docker
  # From https://nixos.wiki/wiki/Nvidia
  # Warning keeps telling me to:
  virtualisation.docker = {
    daemon.settings.features.cdi = true;
    enable = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

  xdg.portal.configPackages = with pkgs; [
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gnome  # For niri
  ];

  khome = {
    tuigreet = {
      enable = true;
      enableWaylandEnvs = true;
      sessions = {
        hyprland.enable = true;
        niri.enable = true;
        sway.enable = true;
        zsh.enable = true; # Doesn't work!
      };
    };
  };

  fonts.packages = with pkgs; [
    # Noto: means no tofu. Tofu is the colloquial term for errors in rendering chinese characters
    noto-fonts
    noto-fonts-extra
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    babelstone-han # unicode font with loooads of Han characters

    font-awesome # NOTE do I need this?
    material-symbols

    fira-code-symbols # NOTE might not be needed with nord-fonts.firacode
    nerd-fonts.fira-code
    nerd-fonts.iosevka
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    grub.configurationLimit = 42;
  };

  # Set your time zone.
  # services.automatic-timezoned.enable = true;
  # For manual timezones
  time.timeZone = "America/New_York";
  # time.timeZone = "Europe/Paris";

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
      {
        manage = "window";
        name = "sway";
        start = "sway";
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
  users.users.daniel = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
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
