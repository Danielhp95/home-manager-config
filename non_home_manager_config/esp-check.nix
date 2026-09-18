# `esp-check`: proves that what the firmware will load at the next boot matches
# the system profile. It runs at the end of every bootloader install (`nh os
# boot` / `nh os switch`), where a failure aborts the install with a non-zero
# exit instead of the silent success that hid the 2026-09 boot incident, and it
# is on PATH for a manual look (it re-execs itself through sudo: the ESP is
# mounted fmask/dmask 0077, so unprivileged every file below reads as absent).
#
# Why this exists (2026-09-09..12): the laptop dropped to `grub rescue>` with
# "symbol 'grub_memcpy' not found". The ESP held three loaders sharing one GRUB
# module directory (/boot/grub/x86_64-efi): NixOS's own core image, an older
# GRUB core hand-copied over /EFI/ubuntu/shimx64.efi in 2025-12 (the
# file the firmware's "ubuntu" entry, first in BootOrder, loads), and a
# systemd-boot left over from the original 25.11 install whose only entry
# pointed at a closure deleted months ago. A nixpkgs bump refreshed the modules;
# the older core could not load them; the systemd-boot fallback booted a
# kernel with no module tree on disk. A plain `nixos-rebuild` reports none of
# that. The loader policy itself lives in hardwares/new_fell_omen.nix.
#
# 2026-09-13: the fix above missed the disguised core (only a file named
# grubx64.efi was looked for) and the HP firmware re-created the deleted
# "ubuntu" entry on its own, so the rescue prompt came back. Hence
# `khome.espCheck.loaderMirrors` and the per-NVRAM-entry check below.
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
  mirrors = map (m: "${esp}/${m}") config.khome.espCheck.loaderMirrors;

  # Runs as root between grub-install and esp-check. Unconditional: grub-install
  # only re-runs when its state file changes, but a mirror must follow the
  # image every time it does.
  esp-sync-mirrors = pkgs.writeShellApplication {
    name = "esp-sync-mirrors";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
    ];
    text = lib.concatMapStrings (m: ''
      if ! cmp -s ${loaderImage} ${m}; then
        mkdir -p "$(dirname ${m})"
        cp ${loaderImage} ${m}.tmp
        mv ${m}.tmp ${m}
        echo "esp-check: refreshed ${m} from ${loaderImage}"
      fi
    '') mirrors;
  };

  esp-check = pkgs.writeShellApplication {
    name = "esp-check";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      gnugrep
      gnused
      diffutils
      findutils
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

      # 2b. Loader mirrors are byte copies of that image.
      mirrors=(${lib.escapeShellArgs mirrors})
      for m in "''${mirrors[@]}"; do
        if ! cmp -s "$img" "$m"; then
          bad "$m is not a copy of $img: the firmware entry that loads it would start a different GRUB core (grub rescue> \"symbol 'grub_memcpy' not found\"); run nh os boot to refresh it"
        fi
      done

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
      #    $esp/grub/x86_64-efi with ours and breaks on the next nixpkgs bump,
      #    whatever its file is called (the 2026-09 one was named shimx64.efi);
      #    systemd-boot leftovers list closures that no longer exist. Warnings
      #    only: nothing may load them (6. checks that), and removing them is a
      #    manual root step.
      while IFS= read -r -d "" f; do
        if ! cmp -s "$f" "$img" && grep -a -q 'grub_' "$f"; then
          warn "GRUB core not written by this install: $f"
        fi
      done < <(find "$esp/EFI" -type f -iname '*.efi*' -print0)
      for stale in \
        "$esp/EFI/NixOS-boot" \
        "$esp/EFI/systemd" \
        "$esp/EFI/nixos" \
        "$esp/loader/entries"; do
        if [ -e "$stale" ]; then
          warn "stale loader files: $stale"
        fi
      done

      # 6. What every firmware entry loads. Deleting an entry does not stick on
      #    this HP firmware (it re-created "ubuntu" -> \EFI\ubuntu\shimx64.efi
      #    by itself within a day), so the check is on the file, not the entry:
      #    a GRUB core other than ours behind any entry fails the install.
      if order="$(efibootmgr 2>/dev/null)"; then
        echo "$order" | grep -E '^(BootOrder|Boot[0-9A-F]{4})' | sed 's/^/  /'
        while read -r entry file; do
          target="$esp$file"
          if [ ! -f "$target" ]; then
            warn "$entry points at missing $file; delete with: efibootmgr -b ''${entry#Boot} -B"
          elif ! cmp -s "$target" "$img"; then
            if grep -a -q 'grub_' "$target"; then
              bad "$entry loads $file, a GRUB core other than $img that cannot load this install's modules; list it in khome.espCheck.loaderMirrors"
            else
              warn "$entry loads $file, which is not this install's GRUB"
            fi
          fi
        done < <(printf '%s\n' "$order" \
          | sed -nE 's/^(Boot[0-9A-F]{4})\*? .*(\\EFI\\[^[:space:]]*\.[Ee][Ff][Ii]).*/\1 \2/p' \
          | tr '\134' /)
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
  options.khome.espCheck.loaderMirrors = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "EFI/ubuntu/shimx64.efi" ];
    description = ''
      ESP-relative paths kept as byte copies of the removable GRUB image,
      refreshed on every bootloader install. For firmware that insists on
      booting a path of its own choosing: whatever it loads is then this
      install's GRUB, and esp-check fails the install if a copy drifts.
    '';
  };

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
    boot.loader.grub.extraInstallCommands = ''
      ${esp-sync-mirrors}/bin/esp-sync-mirrors
      ${esp-check}/bin/esp-check
    '';
  };
}
