# `esp-check`: proves that what the firmware will load at the next boot matches
# the system profile. It runs at the end of every bootloader install (`nh os
# boot` / `nh os switch`), where a failure aborts the install with a non-zero
# exit instead of the silent success that hid the 2026-09 boot incident, and it
# is on PATH for a manual look (it re-execs itself through sudo: the ESP is
# mounted fmask/dmask 0077, so unprivileged every file below reads as absent).
#
# Why this exists (2026-09-09..12): the laptop dropped to `grub rescue>` with
# "symbol 'grub_memcpy' not found". The ESP held three loaders sharing one GRUB
# module directory (/boot/grub/x86_64-efi): NixOS's own core image, a foreign
# core at /EFI/ubuntu/grubx64.efi that was first in the firmware's BootOrder,
# and a systemd-boot left over from the original 25.11 install whose only entry
# pointed at a closure deleted months ago. A nixpkgs bump refreshed the modules;
# the foreign core could not load them; the systemd-boot fallback booted a
# kernel with no module tree on disk. A plain `nixos-rebuild` reports none of
# that. The loader policy itself lives in hardwares/new_fell_omen.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.boot.loader.grub;
  esp = config.boot.loader.efi.efiSysMountPoint;
  espDevice = config.fileSystems.${esp}.device;
  # grub-install --removable writes here; the firmware's "Internal Hard Disk"
  # entry loads it without consulting NVRAM.
  loaderImage = "${esp}/EFI/BOOT/BOOTX64.EFI";

  esp-check = pkgs.writeShellApplication {
    name = "esp-check";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      gnugrep
      gnused
      diffutils
      efibootmgr
    ];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
      fi

      esp=${esp}
      fail=0
      bad() { echo "ESP CHECK FAILED: $*" >&2; fail=1; }
      warn() { echo "esp-check warning: $*" >&2; }

      # 1. The mount is the real ESP, not the empty directory underneath it.
      expected_dev="$(readlink -f ${espDevice})"
      actual_dev="$(findmnt -no SOURCE "$esp" || true)"
      actual_type="$(findmnt -no FSTYPE "$esp" || true)"
      if [ -z "$actual_dev" ]; then
        bad "$esp is not a mountpoint; bootloader output would land on the root filesystem"
      elif [ "$actual_dev" != "$expected_dev" ] || [ "$actual_type" != "vfat" ]; then
        bad "$esp is $actual_dev ($actual_type), expected $expected_dev (vfat)"
      fi

      # 2. The removable-path image is GRUB (its kernel keeps every exported
      #    symbol name in plain text) and not a leftover systemd-boot.
      img=${loaderImage}
      if [ ! -f "$img" ]; then
        bad "$img missing: rebuild with --install-bootloader"
      elif grep -a -q 'systemd-boot' "$img"; then
        bad "$img is still systemd-boot, not GRUB: rebuild with --install-bootloader (grub-install only re-runs when its state file changes, and that file ignores efiInstallAsRemovable)"
      elif ! grep -a -q 'grub_' "$img"; then
        bad "$img is not a GRUB image"
      fi

      # 3. The menu on the ESP has an entry for the current generation.
      system="$(readlink -f /nix/var/nix/profiles/system)"
      if ! grep -q -F "init=$system/init" "$esp/grub/grub.cfg" 2>/dev/null; then
        bad "$esp/grub/grub.cfg has no entry for $system"
      fi

      # 4. The kernel and initrd copies GRUB will load are the profile's
      #    (copyKernels: /boot is a different filesystem from the store).
      for part in kernel initrd; do
        src="$(readlink -f "$system/$part")"
        name="$(printf '%s' "''${src#/nix/store/}" | tr / -)"
        copy="$esp/kernels/$name"
        if [ ! -e "$copy" ]; then
          bad "$copy missing (profile $part: $src)"
        elif ! cmp -s "$copy" "$src"; then
          bad "$copy differs from $src"
        fi
      done

      # 5. Other loaders on the ESP. Every extra GRUB core shares
      #    $esp/grub/x86_64-efi with ours and breaks on the next nixpkgs bump;
      #    systemd-boot leftovers list closures that no longer exist. Warnings
      #    only: removing them is a manual root step.
      for stale in \
        "$esp/EFI/ubuntu/grubx64.efi" \
        "$esp/EFI/ubuntu/grubx64.efi.backup" \
        "$esp/EFI/NixOS-boot" \
        "$esp/EFI/systemd" \
        "$esp/EFI/nixos" \
        "$esp/loader/entries"; do
        if [ -e "$stale" ]; then
          warn "stale loader files: $stale"
        fi
      done

      # 6. Firmware entries the firmware would try before the removable path.
      if order="$(efibootmgr 2>/dev/null)"; then
        echo "$order" | grep -E '^(BootOrder|Boot[0-9A-F]{4})' | sed 's/^/  /'
        if echo "$order" | grep -qE '^Boot[0-9A-F]{4}\*? +(ubuntu|Linux Boot Manager|NixOS-boot)'; then
          warn "stale NVRAM entries above (ubuntu / Linux Boot Manager / NixOS-boot); delete with: efibootmgr -b XXXX -B"
        fi
      fi

      # 7. Headroom: installs fail quietly on a full ESP.
      df -h "$esp" | tail -1 | sed 's/^/  /'
      use="$(df --output=pcent "$esp" | tail -1 | tr -dc '0-9')"
      if [ "$use" -ge 80 ]; then
        warn "$esp is $use% full"
      fi

      if [ "$fail" -ne 0 ]; then
        exit 1
      fi
      echo "ESP in sync: $img boots $system"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.efiInstallAsRemovable;
        message = "esp-check.nix: boot.loader.grub.efiInstallAsRemovable must be true. This firmware drops NixOS's NVRAM entry from BootOrder; only the removable path /EFI/BOOT/BOOTX64.EFI is loaded deterministically.";
      }
    ];

    environment.systemPackages = [
      esp-check
      # `efibootmgr` (and `bootctl status`) answer "what will the firmware
      # load?", the question a successful rebuild never answers.
      pkgs.efibootmgr
    ];

    # install-grub.sh runs under `set -e`, so a failing check here fails the
    # bootloader install and the rebuild reports it.
    boot.loader.grub.extraInstallCommands = "${esp-check}/bin/esp-check";
  };
}
