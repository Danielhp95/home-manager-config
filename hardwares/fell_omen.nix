# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ "dm-snapshot" "amdgpu"];
  # boot.initrd.luks.devices.root.device = "/dev/disk/by-uuid/dacb058a-cf2e-4646-93a5-c2efe21de50b";
  boot.kernelModules = [ "kvm-amd" ];
  # This line is needed to fix suspend/wakeup issues in Hyprland
  # https://wiki.hyprland.org/Nvidia/#fixing-suspendwakeup-issues
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"  # To prevent nvidia from crashing on suspend. DOES NOT WORK when other monitors are connected
    "nvidia-drm.modeset=1"   # Needed for `gamescope`
  ];
  boot.extraModulePackages = [ ];

  services = {
    xserver.videoDrivers = [ "nvidia" "amdgpu"]; # Have nvidia and amd GPUs active
    logind.lidSwitchDocked = "suspend"; # Suspend when laptop lid is closed but computer is docked to monitors / keyboard
  };

  hardware = {
    graphics = {
    # Apparently necessary for davinci. Not sure
      enable = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        intel-compute-runtime
      ];
      enable32Bit = true;
    };
    nvidia = {
      # package = let
      #   rcu_patch = pkgs.fetchpatch {
      #     url = "https://github.com/gentoo/gentoo/raw/c64caf53/x11-drivers/nvidia-drivers/files/nvidia-drivers-470.223.02-gpl-pfn_valid.patch";
      #     hash = "sha256-eZiQQp2S/asE7MfGvfe6dA/kdCvek9SYa/FFGp24dVg=";
      #   };
      #   in
      #   config.boot.kernelPackages.nvidiaPackages.mkDriver {
      #     version = "555.42.02";
      #     sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
      #     sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #     openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #     settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
      #     persistencedSha256 = "sha256-3ae31/egyMKpqtGEqgtikWcwMwfcqMv2K4MVFa70Bqs=";
      #   };
        # config.boot.kernelPackages.nvidiaPackages.mkDriver {
        #   version = "535.154.05";
        #   sha256_64bit = "sha256-fpUGXKprgt6SYRDxSCemGXLrEsIA6GOinp+0eGbqqJg=";
        #   sha256_aarch64 = "sha256-G0/GiObf/BZMkzzET8HQjdIcvCSqB1uhsinro2HLK9k=";
        #   openSha256 = "sha256-wvRdHguGLxS0mR06P5Qi++pDJBCF8pJ8hr4T8O6TJIo=";
        #   settingsSha256 = "sha256-9wqoDEWY4I7weWW05F4igj1Gj9wjHsREFMztfEmqm10=";
        #   persistencedSha256 = "sha256-d0Q3Lk80JqkS1B54Mahu2yY/WocOqFFbZVBh+ToGhaE=";
        #   patches = [ rcu_patch ];
        # config.boot.kernelPackages.nvidiaPackages.mkDriver {
        #   version = "535.129.03";
        #   sha256_64bit = "sha256-5tylYmomCMa7KgRs/LfBrzOLnpYafdkKwJu4oSb/AC4=";
        #   sha256_aarch64 = "sha256-i6jZYUV6JBvN+Rt21v4vNstHPIu9sC+2ZQpiLOLoWzM=";
        #   openSha256 = "sha256-/Hxod/LQ4CGZN1B1GRpgE/xgoYlkPpMh+n8L7tmxwjs=";
        #   settingsSha256 = "sha256-QKN/gLGlT+/hAdYKlkIjZTgvubzQTt4/ki5Y+2Zj3pk=";
        #   persistencedSha256 = "sha256-FRMqY5uAJzq3o+YdM2Mdjj8Df6/cuUUAnh52Ne4koME=";
        #   patches = [ rcu_patch ];
      # };
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      open = false;  # Don't use open source drivers (use closed-source)
      nvidiaSettings = true;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make sure to use the correct Bus ID values for your system!
        # This can be retrieved by running: sudo lshw -c display
        amdgpuBusId = "PCI:06:00:0";
        nvidiaBusId = "PCI:01:00:0";
      };
    };

    # Bluetooth 
    bluetooth = {
      enable = true;
    };

    # TODO: figure out what this does
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  # Use headphone buttons to control media player: https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
  systemd.user.services = {
    mpris-proxy = {
      description = "Mpris proxy";
      after = [ "network.target" "sound.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
    };

    polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/9198a171-af25-4994-adc0-29dfebf18890";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/D0C6-BF0B";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/a7497916-c6b3-4da5-b587-ff8b0ce3ce20"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with expliciv per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
