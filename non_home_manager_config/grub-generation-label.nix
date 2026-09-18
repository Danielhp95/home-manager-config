# Stamps the current generation number onto the GRUB menu's top-level NixOS
# entries ("NixOS - Default", "NixOS - dGPU HDMI", ...).
#
# Why a hook and not an option: install-grub.pl builds those entries with
# addGeneration("NixOS", "", $defaultConfig, ..., 1) — a hardcoded name and an
# empty suffix. Only the "All configurations" submenu is numbered, because
# there the number comes from the profile symlink's own name (system-N-link).
#
# It cannot come from the build either. Nix realises the system closure before
# `nix-env --set` hands it a generation number, so no file under /nix/store can
# name it — the same reason the specialisation rows used to read 1969-12-31
# (every store timestamp is pinned to epoch+1). The number is first knowable at
# bootloader-install time, which is where this puts it in.
#
# Cosmetic only, so it never fails the install: it refuses to write unless the
# rewrite provably touched nothing but `menuentry` title strings. The kernel,
# initrd and init= lines esp-check verifies right afterwards come through
# byte-identical or the original file stays.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.boot.loader.grub;
  esp = config.boot.loader.efi.efiSysMountPoint;

  grub-stamp-generation = pkgs.writeShellApplication {
    name = "grub-stamp-generation";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gnugrep
      gnused
    ];
    text = ''
      toplevel=''${1:-}
      conf="${esp}/grub/grub.cfg"
      profile=/nix/var/nix/profiles/system
      tmp="$conf.stamp.tmp"

      # Only label the menu when the profile really points at the system being
      # installed; otherwise the number would name a different closure than the
      # entries boot (a hand-run install-bootloader, say).
      if [ -z "$toplevel" ] || [ "$(readlink -f "$profile")" != "$(readlink -f "$toplevel")" ]; then
        echo "grub-stamp-generation: $profile does not point at the system being installed; menu left unlabelled" >&2
        exit 0
      fi

      link=$(readlink "$profile") # system-341-link
      gen=''${link#system-}
      gen=''${gen%-link}
      if ! printf '%s' "$gen" | grep -qE '^[0-9]+$'; then
        echo "grub-stamp-generation: no generation number in $profile -> $link; menu left unlabelled" >&2
        exit 0
      fi

      # Every row of the "All configurations" submenu already carries its own
      # number, so branch past those and append to the rest. `submenu` lines are
      # left alone by the anchor, as is the Ubuntu entry.
      sed -E '/^menuentry "NixOS - Configuration [0-9]/b
              s/^menuentry "(NixOS[^"]*)"/menuentry "\1 (generation '"$gen"')"/' "$conf" > "$tmp"

      # Prove the rewrite changed titles and nothing else before it goes near
      # the boot path: same number of entries, every other line identical.
      if [ "$(grep -c '^menuentry ' "$tmp" || true)" = "$(grep -c '^menuentry ' "$conf" || true)" ] &&
         diff -q <(grep -v '^menuentry ' "$conf") <(grep -v '^menuentry ' "$tmp") > /dev/null; then
        mv "$tmp" "$conf"
      else
        rm -f "$tmp"
        echo "grub-stamp-generation: refusing to write, the rewrite changed more than entry titles" >&2
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # mkBefore: esp-check.nix appends its own commands to this option and has to
    # validate the grub.cfg that ends up on disk, so this must run first.
    boot.loader.grub.extraInstallCommands = lib.mkBefore ''
      ${grub-stamp-generation}/bin/grub-stamp-generation "$1"
    '';
  };
}
