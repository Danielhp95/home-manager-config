# Stamps the generation number onto the GRUB menu's top-level entries
# ("NixOS - Default", "NixOS - Roadwarrior"). install-grub.pl hardcodes those
# names and the build can't know the number, so this runs at install time.
# Cosmetic: it never fails, and writes only if nothing but titles changed.
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
      # left alone by the anchor.
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
    # mkBefore: esp-check.nix must validate the grub.cfg this rewrites.
    boot.loader.grub.extraInstallCommands = lib.mkBefore ''
      ${grub-stamp-generation}/bin/grub-stamp-generation "$1"
    '';
  };
}
