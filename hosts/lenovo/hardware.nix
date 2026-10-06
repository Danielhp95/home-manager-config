# Lenovo ThinkPad T16g Gen 3 (21V6): Core Ultra 9 285HX (Arrow Lake-HX),
# RTX 5090 Laptop (Blackwell), 3840x2400 panel, SoundWire audio.
{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  # nvme0n1p1 ESP, p2 LUKS -> ext4 root, p3 LUKS -> swap.
  luksUuid = "6e1bc8e1-f482-4b9a-8360-674b0438ac0b";
  swapLuksUuid = "62222a60-c16a-45da-a034-8ecfa93ef3e8";
  espUuid = "7D69-4C07";

  # PCI:bus:device:function in decimal (the option rejects hex):
  # lspci's "0a:00.0" is "PCI:10:0:0".
  intelBusId = "PCI:0:2:0"; # 00:02.0 Arrow Lake-S iGPU
  nvidiaBusId = "PCI:1:0:0"; # 01:00.0 GB203M RTX 5090 Laptop

  luksDevice = "/dev/mapper/luks-${luksUuid}";
  swapLuksDevice = "/dev/mapper/luks-${swapLuksUuid}";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../bluetooth.nix

    # nixos-hardware has no T16g or Arrow Lake profile; these are the parts
    # that fit. Meteor Lake (same Xe-LPG iGPU): microcode, i915 in the initrd
    # (early KMS for the LUKS prompt), iHD, vpl-gpu-rt. Not the same-silicon
    # lenovo-legion-16iax10h: its EC module, HDA quirk and bus IDs are Legion's.
    "${inputs.nixos-hardware}/common/cpu/intel/meteor-lake"
    "${inputs.nixos-hardware}/common/gpu/nvidia/blackwell"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-intel" ];

    # spd5118 (DDR5 DIMM temperature sensors) fails every s2idle resume with
    # -ENXIO; blacklisting costs only the DIMM temperature readout.
    blacklistedKernelModules = [ "spd5118" ];

    kernelParams = [
      "quiet"
      "mitigations=off"
    ];

    initrd = {
      systemd.enable = true;
      verbose = false;
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sdhci_pci"
      ];
      luks.devices."luks-${luksUuid}" = {
        device = "/dev/disk/by-uuid/${luksUuid}";
        allowDiscards = true;
      };
      luks.devices."luks-${swapLuksUuid}".device = "/dev/disk/by-uuid/${swapLuksUuid}";
    };

    loader = {
      timeout = 5;
      efi = {
        canTouchEfiVariables = false; # nixpkgs asserts this off for removable
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
        # Pinned rather than auto-detected: esp-check verifies the
        # /boot/kernels/<store-name> copies.
        copyKernels = true;
        useOSProber = false;
        # 1 GB ESP: a generation with its own kernel costs ~116 MB (kernel +
        # two initrds), so 6 stays under esp-check's 80% warning. nh.clean's
        # `--keep` is derived from this (configuration.nix).
        configurationLimit = 6;

        # The splash is the scene with the SOUL heart in the corner, shown once
        # an entry is picked, so the heart seems to jump from the menu.
        theme = pkgs.callPackage ../../grub_theme { };
        splashImage = "${config.boot.loader.grub.theme}/background-selected.png";
        splashMode = "stretch";
        # gfxmodeEfi stays "auto": the GOP offers no 1920x1200, so GRUB runs at
        # native 3840x2400, the mode the theme's pixel sizes are authored for.
      };
    };
  };

  # No `discard`: the weekly fstrim.timer TRIMs through LUKS allowDiscards.
  fileSystems."/" = {
    device = luksDevice;
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/${espUuid}";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
      # Fail fast if the ESP is missing. Not "nofail": a rebuild would then
      # "succeed" without writing the bootloader.
      "x-systemd.device-timeout=5s"
    ];
  };

  # 8.8 GB, behind zram in priority; too small for a hibernation image.
  swapDevices = [ { device = swapLuksDevice; } ];

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    logind.settings.Login.HandleLidSwitchDocked = "suspend";
    logind.settings.Login.HandleLidSwitch = "suspend";

    # Goodix 27c6:6594 in the power button (enrol: fprintd-enroll). Turns on
    # pam_fprintd for every PAM service; greetd and login opt out below.
    fprintd.enable = true;

    # Keep HDMI/DP audio out of device pickers: the dGPU's HDA card (01:00.1)
    # whole, then the SOF card's HDMI sinks. Drop a rule for monitor audio.
    pipewire.wireplumber.extraConfig."51-hide-hdmi-sinks"."monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_01_00.1"; } ];
        actions.update-props."device.disabled" = true;
      }
      {
        matches = [ { "node.name" = "~alsa_output.pci-0000_80_1f.3-platform-sof_sdw.HiFi__HDMI.*"; } ];
        actions.update-props."node.disabled" = true;
      }
    ];
  };

  security.pam.services = {
    # A fingerprint login can't unlock gnome-keyring, and pam_fprintd would
    # stall the greeter's password prompt until it times out.
    greetd.fprintAuth = false;
    # noctalia's lockscreen checks passwords against "login" and drives the
    # reader itself over D-Bus; pam_fprintd there would fight it for the sensor.
    login.fprintAuth = false;
  };

  hardware = {
    enableAllFirmware = true;
    cpu.intel.npu.enable = true;
    graphics = {
      enable = true;
      # iHD, compute-runtime and vpl-gpu-rt come from the meteor-lake import;
      # hyprland.lua forces LIBVA_DRIVER_NAME=iHD, so VA-API depends on it.
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
      ];
      enable32Bit = true;
    };
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      open = true; # Blackwell is only supported by the open kernel modules
      nvidiaSettings = true;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        inherit intelBusId nvidiaBusId;
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
