# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, inputs, ... }:

{
  imports = [ ../tuigreet.nix  ];

  # Authenticator manager
  security.polkit.enable = true;

  nix = {
    settings.extra-experimental-features = ["flakes" "nix-command"];
    gc = {
      automatic = true;
      randomizedDelaySec = "14m";  # What does this do?
      options = "--delete-older-than 15d";
    };
  };

  services.dbus.packages = [ pkgs.gcr ];  # Why do I want this?

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
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };

  xdg.portal.configPackages = [ pkgs.xdg-desktop-portal-hyprland ];

  khome = {
    tuigreet = {
      enable = true;
      enableWaylandEnvs = true;
      sessions = {
        hyprland.enable = true;
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
    babelstone-han  # unicode font with loooads of Han characters

    material-symbols
    lexend
    nerdfonts

    fira-code
    fira-code-symbols
    (nerdfonts.override { fonts = [ "FiraCode" "Iosevka" ]; })
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    grub.configurationLimit = 42;
  };

  networking.hostName = "fell-omen"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  console = lib.mkForce {
    font = "Lat2-Terminus16";
    keyMap = "us";
    useXkbConfig = true; # use xkbOptions in tty.
  };

  # Enable the GNOME Desktop Environment.
  services.xserver = {
    # Enable the X11 windowing system.
    enable = true;
    excludePackages = [ pkgs.xterm ];
    # TODO: remove these two, as gnome leaves breadcrumbs of programs around!
    # Figure out how to get these features without gnome
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;

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

  environment.pathsToLink = [ "/share/zsh" ];  # Make sure that home-manager installed `zsh` picks up system installed programs

  # Commented out because we are not using X
  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  programs.zsh.enable = true;
  users.users.daniel = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # group "wheel" -> sudo access
    packages = with pkgs; [
      firefox
      tree
      vim
      git
    ];
    hashedPassword = "$y$j9T$BS53tFZ/aYhulnHaIPdfV1$RgynhBpss3Mkz6Rliz3nn4KsTaQ9RI1mdB8qLb5OdxC";
  };

  # Does this work?
  # This was meant to fix 
  systemd.services.suspend-hyprland = {
    description = "Suspend hyprland";
    before = [ "systemd-suspend.service" "systemd-hibernate.service" "nvidia-suspend.service" "nvidia-hibernate.service" ];
    wantedBy = [ "systemd-suspend.service" "systemd-hibernate.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "killall -STOP Hyprland";
    };
  };

  systemd.services.resume-hyprland = {
    description = "Resume hyprland";
    after = [ "systemd-suspend.service" "systemd-hibernate.service" "nvidia-resume.service" ];
    wantedBy = [ "systemd-suspend.service" "systemd-hibernate.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "killall -CONT Hyprland";
    };
  };


  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # Shows what closure differences from last generation
  system.activationScripts.diff = ''
    if [[ -e /run/current-system ]]; then
      ${pkgs.nix}/bin/nix store diff-closures /run/current-system "$systemConfig"
    fi
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

