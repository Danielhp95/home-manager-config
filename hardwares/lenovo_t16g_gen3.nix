# Lenovo ThinkPad T16g Gen 3, the machine replacing fell-omen.
#
# Written from Lenovo's order sheet before the laptop arrived, not by
# nixos-generate-config. Values that only exist on the real hardware are
# `throw`s in the `let` below: importing this file before filling them in
# fails evaluation naming the missing value, instead of building a system
# that can't find its own disks. Once installed, also diff this against
# `nixos-generate-config --show-hardware-config` (initrd modules especially).
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
  # ---- Fill in on the machine ---------------------------------------------
  # From `blkid` once the disk is partitioned.
  luksUuid = throw "lenovo_t16g_gen3.nix: set luksUuid (blkid: the crypto_LUKS partition)";
  espUuid = throw "lenovo_t16g_gen3.nix: set espUuid (blkid: the vfat ESP)";

  # From `lspci -d ::03xx`, written as PCI:bus:device:function in decimal
  # (the option's type rejects hex): lspci's "0a:00.0" is "PCI:10:0:0".
  intelBusId = throw "lenovo_t16g_gen3.nix: set intelBusId (lspci -d ::03xx)";
  nvidiaBusId = throw "lenovo_t16g_gen3.nix: set nvidiaBusId (lspci -d ::03xx)";
  # -------------------------------------------------------------------------

  luksDevice = "/dev/mapper/luks-${luksUuid}";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../bluetooth.nix

    # ---- nixos-hardware ---------------------------------------------------
    # Nothing there matches this machine: no T16g, no P16 (only P16s), and no
    # Arrow Lake modules (checked at rev 83bbc89). The closest composition is
    # what lenovo-legion-16iax10h (Arrow Lake-HX + RTX 50) imports, minus its
    # Legion-only parts, plus the generic ThinkPad profile. Needs an input:
    #   nixos-hardware.url = "github:NixOS/nixos-hardware";
    #   nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
    #
    # Evaluated against this file, the four imports below only add: i915 in
    # the initrd, vpl-gpu-rt, 32-bit intel-media-driver, and
    # hardware.trackpoint. Everything else they set is already explicit here.
    #
    # hardware.trackpoint is a udev rule tuning the stick's sysfs attributes,
    # matched on hardware.trackpoint.device ("TPPS/2 IBM TrackPoint" unless
    # set; check `libinput list-devices`), plus X11-only wheel emulation.
    # Also pulls in common-pc-laptop, which enables TLP (already on):
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad
    # Microcode + Intel iGPU userspace. Meteor Lake's module rather than
    # common-cpu-intel: same Xe-LPG iGPU generation, and it skips the i965
    # VA-API driver and intel-ocl the generic one adds.
    # "${inputs.nixos-hardware}/common/cpu/intel/meteor-lake"
    # PRIME offload, and open kernel modules for Blackwell:
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # "${inputs.nixos-hardware}/common/gpu/nvidia/blackwell"
    #
    # Whole-machine profiles, and why not:
    # inputs.nixos-hardware.nixosModules.lenovo-legion-16iax10h
    #   Same silicon, wrong machine: adds the Legion EC kernel module, an HDA
    #   speaker quirk (this has SoundWire), dpi = 189 for a 2560x1600 panel,
    #   and sets both bus IDs at normal priority, so any value below that
    #   isn't the identical string fails with a conflicting-definition error.
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p16s-intel-gen3
    #   Nearest ThinkPad by name. Today it evaluates to exactly the same
    #   system as the four imports above, but it's written for Meteor Lake +
    #   RTX Ada, so whatever it gains later targets those chips, not these.
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
      # fell-omen needs acpi_backlight=native because its EC registered
      # nvidia_wmi_ec_backlight instead of intel_backlight. Check
      # `ls /sys/class/backlight` in Hybrid mode before copying it. Expect a
      # phantom `nvidia_0` here too (a BIOS Discrete mode means the dGPU has
      # its own eDP link), which is why hyprland.lua and noctalia name
      # intel_backlight explicitly instead of trusting brightnessctl's pick.
      # "acpi_backlight=native"

      # Serial console printk is synchronous and surprisingly slow during
      # boot; errors still print (loglevel unaffected for warnings+).
      "quiet"
      # Deliberate security tradeoff, accepted 2026-08-06 on fell-omen:
      # disables Spectre-class speculative-execution mitigations for
      # measurable syscall/IO speedup. Remove this line to restore full
      # mitigation.
      "mitigations=off"
    ];

    initrd = {
      # systemd stage 1: parallel device probing, an earlier LUKS prompt, and
      # initrd time that decomposes in `systemd-analyze blame --initrd`.
      systemd.enable = true;
      verbose = false;
      # fell-omen's detected list as a starting point; replace it with what
      # nixos-generate-config finds here.
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      luks.devices."luks-${luksUuid}" = {
        device = "/dev/disk/by-uuid/${luksUuid}";
        # TRIM through dm-crypt so discard=async and fstrim.timer reach the
        # SSD. Tradeoff: the raw disk reveals which blocks are unused.
        allowDiscards = true;
      };
    };

    loader = {
      # 5s: enough to actually read the entries (1s wasn't).
      timeout = 5;
      # Removable-path install, same policy as new_fell_omen.nix (see the
      # 2026-09 incident note there): /EFI/BOOT/BOOTX64.EFI is what a
      # firmware's "internal disk" entry loads whatever NVRAM says, and
      # esp-check (non_home_manager_config/esp-check.nix) refuses a rebuild
      # whose ESP disagrees with the profile. The first install on this
      # machine is a fresh one, so no --install-bootloader dance is needed.
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
        configurationLimit = 10;

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

  # Same layout as fell-omen: an ESP plus one LUKS partition holding btrfs
  # subvolumes @ and @home.
  # noatime: no metadata write per file read (store scans, builds, greps).
  # compress=zstd:1: cheap transparent compression, new writes only.
  # discard=async: batched TRIM (needs allowDiscards on the LUKS device).
  # Mount options are per-device on btrfs, so keep both subvol mounts identical.
  fileSystems."/" = {
    device = luksDevice;
    fsType = "btrfs";
    options = [
      "subvol=@"
      "noatime"
      "compress=zstd:1"
      "discard=async"
    ];
  };
  fileSystems."/home" = {
    device = luksDevice;
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "noatime"
      "compress=zstd:1"
      "discard=async"
    ];
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

  swapDevices = [ ];

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    logind.settings.Login.HandleLidSwitchDocked = "suspend"; # Suspend when the lid closes while docked
    logind.settings.Login.HandleLidSwitch = "suspend"; # What to do when the laptop lid is closed
  };

  # Audio is SoundWire (CS42L43 codec + CS35L56 amps), not fell-omen's HDA
  # codec. The amps load per-model firmware/tuning from linux-firmware
  # (enableAllFirmware below); if the speakers are silent or very quiet,
  # start with `journalctl -b -k | grep -i cs35l56`.
  #
  # fell-omen hides the dGPU's HDMI pro-output sinks and the codec's unplugged
  # HDMI sinks. The node names embed the PCI address and ALSA card profile, so
  # its patterns won't match here; take the real ones from `wpctl status`.
  # services.pipewire.wireplumber.extraConfig."51-hide-unwanted-sinks" = {
  #   "monitor.alsa.rules" = [
  #     {
  #       matches = [
  #         { "node.name" = "~alsa_output.pci-0000_<dgpu>.1.pro-output-.*"; }
  #         { "node.name" = "~alsa_output.<codec HDMI sinks>"; }
  #       ];
  #       actions.update-props."node.disabled" = true;
  #     }
  #   ];
  # };

  # Match-on-chip reader in the power button. Check its `lsusb` ID against
  # libfprint's supported devices before enabling; enrol with fprintd-enroll.
  # services.fprintd.enable = true;

  hardware = {
    enableAllFirmware = true; # Enable firmware that is not free
    # Early microcode from the initrd. nixos-generate-config emits this line;
    # fell-omen's hardware file lost it, so it evaluates to false there.
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
        intel-compute-runtime
        # iHD VA-API driver: video decode on the iGPU media block. The session
        # already forces LIBVA_DRIVER_NAME=iHD (hyprland/hyprland.lua), so
        # without this package VA-API fails outright and video decodes on CPU.
        intel-media-driver
      ];
      enable32Bit = true;
    };
    nvidia = {
      # fell-omen's current choice. It spent a while on legacy_580 because
      # 595.84 crashed Proton/Wine clients in libnvidia-ptxjitcompiler (see
      # `git log -- hardwares/new_fell_omen.nix`); fall back the same way if
      # that comes back.
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      open = true; # Blackwell is only supported by the open kernel modules
      nvidiaSettings = true;
      # Offload assumes the BIOS Graphics Device setting is Hybrid, with the
      # panel on the iGPU. Discrete mode disables the iGPU this depends on.
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        inherit intelBusId nvidiaBusId;
      };
    };
  };

  # Not hardware-specific, but fell-omen keeps these in its hardware file, so
  # they come along rather than silently disappearing with the move.
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
    # The default 64 MiB download buffer stalls substitution of big closures
    # (nvidia/cuda paths) with "download buffer is full" warnings.
    download-buffer-size = 268435456;
    http-connections = 50;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
