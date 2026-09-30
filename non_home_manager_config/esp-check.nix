# `esp-check`: proves the firmware will boot this system profile, which
# `nixos-rebuild` never checks. Runs after every bootloader install (failure
# aborts it) and on demand (re-execs via sudo: /boot is mounted 0077). GRUB
# boots via the removable path; no NVRAM entry points at NixOS.
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
  # From grub-install --removable; loaded by the firmware's generic NVMe entry.
  loaderImage = "${esp}/EFI/BOOT/BOOTX64.EFI";

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

      # 5. Other loaders (warnings; 6. checks nothing loads them). A foreign
      #    GRUB core shares $esp/grub/x86_64-efi with ours and breaks on the
      #    next nixpkgs bump; systemd-boot leftovers list dead closures.
      while IFS= read -r -d "" f; do
        if ! cmp -s "$f" "$img" && grep -a -q 'grub_' "$f"; then
          warn "GRUB core not written by this install: $f"
        fi
      done < <(find "$esp/EFI" -type f -iname '*.efi*' -print0)
      for stale in \
        "$esp/EFI/systemd" \
        "$esp/EFI/nixos" \
        "$esp/loader/entries"; do
        if [ -e "$stale" ]; then
          warn "stale loader files: $stale"
        fi
      done

      # 6. What every firmware entry loads, checked on the file since firmware
      #    may re-create a deleted entry: a foreign GRUB core behind any entry
      #    fails the install.
      if order="$(efibootmgr 2>/dev/null)"; then
        echo "$order" | grep -E '^(BootOrder|Boot[0-9A-F]{4})' | sed 's/^/  /'
        while read -r entry file; do
          target="$esp$file"
          if [ ! -f "$target" ]; then
            warn "$entry points at missing $file; delete with: efibootmgr -b ''${entry#Boot} -B"
          elif ! cmp -s "$target" "$img"; then
            if grep -a -q 'grub_' "$target"; then
              bad "$entry loads $file, a GRUB core other than $img that cannot load this install's modules; delete the entry (efibootmgr -b ''${entry#Boot} -B) and the file"
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
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.efiInstallAsRemovable;
        message = "esp-check.nix: boot.loader.grub.efiInstallAsRemovable must be true. With canTouchEfiVariables = false no NVRAM entry points at NixOS; the firmware reaches GRUB only through the removable path /EFI/BOOT/BOOTX64.EFI, the image esp-check verifies.";
      }
    ];

    environment.systemPackages = [
      esp-check
      # Answers "what will the firmware load?"
      pkgs.efibootmgr
    ];

    # install-grub.sh runs under `set -e`: a failing check fails the install.
    boot.loader.grub.extraInstallCommands = ''
      ${esp-check}/bin/esp-check
    '';
  };
}
