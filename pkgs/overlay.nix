# Every package this flake adds to nixpkgs or changes in it: packages from
# flake inputs, overrides, and the pinned package sets.
{ inputs, theme }:
final: prev:
let
  system = prev.stdenv.hostPlatform.system;
  hyprland = inputs.hyprland.packages.${system}.hyprland;
in
{
  inherit (inputs.iris.packages.${system}) iris;
  inherit (inputs.omnibin.packages.${system}) omnibin omnibin-shell;
  # ~/.face and the greeter's icon, on the palette's surface (./avatar).
  avatar = import ./avatar {
    pkgs = final;
    inherit theme;
  };
  # Steps every output sink at once: the bar's volume pill and hyprland.lua's
  # volume keys.
  volume-all-sinks = final.callPackage ./volume-all-sinks/package.nix { };
  # Upstream's release, patched for the store (./penguin-mail).
  penguin-mail = final.callPackage ./penguin-mail/package.nix { };
  # danvim with the selected palette injected (./danvim.nix).
  danvim = import ./danvim.nix { inherit inputs system theme; };
  # hy3 links against Hyprland's headers: build it against this Hyprland.
  inherit hyprland;
  hy3 = inputs.hy3.packages.${system}.hy3.override { inherit hyprland; };
  inherit (inputs.hyprland.packages.${system}) xdg-desktop-portal-hyprland;
  # Patched; each body sits beside the configuration that depends on it.
  wl-kbptr = final.callPackage ../home/hyprland/wl-kbptr/package.nix { inherit (prev) wl-kbptr; };
  hyprland-preview-share-picker = final.callPackage ../home/hyprland/share-picker/package.nix {
    picker = inputs.hyprland-preview-share-picker.packages.${system}.default;
  };
  # Without mbrola: its voices are ~645 MB and nothing here uses them.
  espeak-ng = prev.espeak-ng.override { mbrolaSupport = false; };
  # The release branch, for packages pinned to it (pkgs.stable.<name>).
  stable = import inputs.stable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  # nixos-unstable at a date or commit: (pkgs.multiverse.at "2026-10-02").<name>.
  multiverse = inputs.multiverse.lib.mkMultiverse {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
}
