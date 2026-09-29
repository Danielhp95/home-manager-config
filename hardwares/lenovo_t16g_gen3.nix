# Lenovo ThinkPad T16g Gen 3, the machine replacing fell-omen.
#
# Written from Lenovo's order sheet before the laptop arrived, then filled in
# on the machine from the stock NixOS install's hardware-configuration.nix
# (disk UUIDs, initrd modules) and lspci (PRIME bus IDs).
#
# Order sheet, decoded. Starred items come from the ThinkPad P16 Gen 3 spec,
# which shares this board ("System Unit: P16G3"); confirm them on arrival.
#   CPU          Core Ultra 9 285HX, 24C/24T, Arrow Lake-HX (fell-omen: 275HX)
#   dGPU         GeForce RTX 5090 Laptop, 24 GB GDDR7 (Blackwell)
#   Panel        16" 3840x2400, 800 nit, HDR, P3, factory calibrated; 60 Hz*
#   RAM          64 GB DDR5-5600, 2x32 GB SO-DIMM; 4 slots*
#   Storage      2 TB M.2 2280 PCIe Gen5 TLC, Opal; 3 M.2 slots*
#   WLAN / BT    Intel BE200 (Wi-Fi 7) + Bluetooth
#   Ethernet     Intel I226* (igc, in-tree)
#   Audio        Cirrus CS42L43 codec + CS35L56 amps* (SoundWire, not HDA)
#   Camera       5 MP RGB+IR with computer vision; USB*
#   Fingerprint  match-on-chip, in the power button*
#   Thunderbolt  2x TB5 + 1x TB4*
#   Security     discrete TPM 2.0, vPro Enterprise (AMT)
#   Power        99.9 Wh battery, 180 W USB-C charger
{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  # ---- Machine values -----------------------------------------------------
  # From `blkid` on the installed disk (NixOS installer layout, 2026-09):
  # nvme0n1p1 ESP, p2 LUKS -> ext4 root, p3 LUKS -> swap.
  luksUuid = "6e1bc8e1-f482-4b9a-8360-674b0438ac0b";
  swapLuksUuid = "62222a60-c16a-45da-a034-8ecfa93ef3e8";
  espUuid = "7D69-4C07";

  # From `lspci -d ::03xx`, written as PCI:bus:device:function in decimal
  # (the option's type rejects hex): lspci's "0a:00.0" is "PCI:10:0:0".
  intelBusId = "PCI:0:2:0"; # 00:02.0 Arrow Lake-S iGPU
  nvidiaBusId = "PCI:1:0:0"; # 01:00.0 GB203M RTX 5090 Laptop
  # -------------------------------------------------------------------------

  luksDevice = "/dev/mapper/luks-${luksUuid}";
  swapLuksDevice = "/dev/mapper/luks-${swapLuksUuid}";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../bluetooth.nix

    # ---- nixos-hardware ---------------------------------------------------
    # Nothing there matches this machine: no T16g, no P16 (only P16s), and no
    # Arrow Lake modules (re-checked on the machine at rev 30d48a0). The
    # closest composition is what lenovo-legion-16iax10h (Arrow Lake-HX + RTX
    # 50) imports, minus its Legion-only parts.
    #
    # Microcode + Intel iGPU. Meteor Lake's module rather than
    # common-cpu-intel: same Xe-LPG iGPU generation, and it skips the i965
    # VA-API driver and intel-ocl the generic one adds. Over this file alone it
    # adds i915 in the initrd (early KMS: the LUKS prompt comes up at native
    # resolution on the right driver instead of efifb), vpl-gpu-rt (Quick Sync
    # through oneVPL), and 32-bit intel-media-driver (VA-API for 32-bit games
    # under Steam/Wine). Its driver choice is i915, which is what binds 00:02.0
    # today; xe on Arrow Lake still needs force_probe.
    "${inputs.nixos-hardware}/common/cpu/intel/meteor-lake"
    # Open kernel modules for Blackwell (already explicit below; imported so
    # Blackwell-wide fixes land here too):
    "${inputs.nixos-hardware}/common/gpu/nvidia/blackwell"
    #
    # Left out:
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad
    #   Only adds hardware.trackpoint (a udev rule writing the stick's sysfs
    #   tuning at its default values, matched on "TPPS/2 IBM TrackPoint"; this
    #   one is "TPPS/2 Elan TrackPoint") plus X11-only wheel emulation, and
    #   common-pc-laptop's TLP, which is already on.
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia (prime.nix)
    #   PRIME offload, set explicitly below.
    #
    # Whole-machine profiles, and why not:
    # inputs.nixos-hardware.nixosModules.lenovo-legion-16iax10h
    #   Same silicon, wrong machine: adds the Legion EC kernel module, an HDA
    #   speaker quirk (this has SoundWire), dpi = 189 for a 2560x1600 panel,
    #   and sets both bus IDs at normal priority, so any value below that
    #   isn't the identical string fails with a conflicting-definition error.
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p16s-intel-gen3
    #   Nearest ThinkPad by name, even the same bus IDs. Today it evaluates to
    #   the two imports above plus lenovo-thinkpad, but it's written for Meteor
    #   Lake + RTX Ada, so whatever it gains later targets those chips.
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-intel" ];

    # fell-omen blacklists spd5118 (the DDR5 SPD temperature sensor): on that
    # board the chip stopped answering on the SMBus after suspend, flooding
    # resume with -ENXIO and sometimes wedging it. Suspend/resume here first;
    # copy it only if `journalctl -b -k | grep spd5118` shows the same thing.
    # blacklistedKernelModules = [ "spd5118" ];

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
        # The installer turns this on by itself when /boot is a different
        # filesystem from the store; pinned so the ESP layout esp-check
        # verifies (/boot/kernels/<store-name>) never depends on detection.
        copyKernels = true;
        useOSProber = false;
        # Must stay <= programs.nh.clean's `--keep N` (configuration.nix).
        # Sized for the installer's 1 GB ESP: a generation with its own kernel
        # costs ~116 MB there (14 MB kernel + a 51 MB initrd each for the
        # default and roadwarrior, whose initrd differs), so 6 stays under
        # esp-check's 80% warning even if every one is distinct; 10 could
        # fill it and fail the install.
        configurationLimit = 6;

        # Undertale mirror-scene theme: the boot menu renders inside the
        # "Despite everything, it's still you." dialogue box. After an entry
        # is chosen GRUB shows its terminal background; pointing that at the
        # scene with the SOUL heart in the corner reads as the soul jumping.
        theme = pkgs.callPackage ../grub_theme { };
        splashImage = "${config.boot.loader.grub.theme}/background-selected.png";
        splashMode = "stretch";
        # The theme is authored at 1920x1200, exactly half this panel on each
        # axis. Its layout is in percentages but its fonts and heart cursor
        # are fixed pixel sizes, so at native 3840x2400 they draw at half
        # scale. "auto" is the fallback if the firmware's GOP doesn't list
        # 1920x1200 (`videoinfo` at the GRUB prompt shows what it offers).
        gfxmodeEfi = "1920x1200,auto";

        # fell-omen's Ubuntu chainload entry isn't carried: that install lives
        # on fell-omen's disk. If Windows 11 is kept on this one, chainload its
        # boot manager from the shared ESP:
        # extraEntries = ''
        #   menuentry "Windows 11" {
        #     insmod part_gpt
        #     insmod fat
        #     search --set=root --fs-uuid ${espUuid}
        #     chainloader /EFI/Microsoft/Boot/bootmgfw.efi
        #   }
        # '';
      };
    };
  };

  # Kernels >= 6.8 already pick a 16x32 console font on high-res panels (why
  # nixos-hardware's common-hidpi is a no-op here), but on 3840x2400 that is
  # half the size fell-omen's TTY, LUKS prompt and tuigreet render at today.
  # Spleen's 32x64 restores the same 120x37 grid:
  # console = {
  #   earlySetup = true;
  #   font = "${pkgs.spleen}/share/consolefonts/spleen-32x64.psfu";
  # };

  # The stock installer layout, not fell-omen's btrfs one: an ESP, one LUKS
  # partition holding a plain ext4 root (/home included), and a LUKS swap
  # partition.
  # noatime: no metadata write per file read (store scans, builds, greps).
  # No `discard` mount option: TRIM comes from the weekly fstrim.timer (on by
  # default), which reaches the SSD through allowDiscards on the LUKS device.
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
      # Fail fast (5s) instead of systemd's long default wait if the ESP
      # doesn't show up. Deliberately NOT "nofail": nofail is what let a
      # rebuild report success against a missing /boot, leaving the
      # bootloader on a stale kernel whose modules a later GC then deleted
      # out from under it (kernel-bootloader-drift incident).
      "x-systemd.device-timeout=5s"
    ];
  };

  # 8.8 GB, well under RAM, so it can't hold a hibernation image; it backs up
  # zram (configuration.nix), which keeps the higher priority.
  swapDevices = [ { device = swapLuksDevice; } ];

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    logind.settings.Login.HandleLidSwitchDocked = "suspend"; # Suspend when the lid closes while docked
    logind.settings.Login.HandleLidSwitch = "suspend"; # What to do when the laptop lid is closed

    # Match-on-chip reader in the power button: Goodix 27c6:6594, libfprint's
    # goodixmoc driver. Enrol with `fprintd-enroll`. Enabling it turns on
    # pam_fprintd for every PAM service (sudo, polkit, ...); the two below
    # opt out.
    fprintd.enable = true;
  };

  # hyprland.lua checks for this file to also open the NVIDIA card for
  # scanout (Intel stays the render GPU), so outputs wired to the dGPU (HDMI,
  # some USB-C/DP ports) work. Costs ~8W: the dGPU never runtime-suspends
  # while Hyprland holds it open. The Roadwarrior boot entry removes it.
  environment.etc."hypr-dgpu-hdmi".text = "";

  security.pam.services = {
    # A fingerprint login can't unlock gnome-keyring (pam_gnome_keyring needs
    # the password; tuigreet.nix wires it), and pam_fprintd would sit in
    # front of the password prompt until it times out.
    greetd.fprintAuth = false;
    # noctalia's lockscreen checks passwords against "login" while it drives
    # the reader itself over D-Bus (lockscreen.fingerprint, on by default);
    # pam_fprintd in that stack would fight it for the sensor. Costs
    # fingerprint on a bare TTY login.
    login.fprintAuth = false;
  };

  hardware = {
    enableAllFirmware = true; # Enable firmware that is not free
    cpu.intel.npu.enable = true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      # intel-media-driver (iHD, 64- and 32-bit), intel-compute-runtime and
      # vpl-gpu-rt come from nixos-hardware's meteor-lake import. iHD is not
      # optional: the session forces LIBVA_DRIVER_NAME=iHD
      # (hyprland/hyprland.lua), so without it VA-API fails outright and video
      # decodes on CPU.
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

  nix.settings = {
    substituters = [
      # Cache for CUDA things
      "https://cuda-maintainers.cachix.org"
      # nix-community hosts neovim-nightly-overlay builds (danvim wraps nvim
      # nightly) plus much of the rest of the nix-community ecosystem.
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    download-buffer-size = 268435456;
    http-connections = 50;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # The release this machine was installed with (NixOS 26.05, 2026-09), not
  # fell-omen's 23.05: stateful defaults must match what's on this disk.
  # Never bump it.
  system.stateVersion = "26.05";
}
