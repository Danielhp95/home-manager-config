# Nix itself: the daemon's settings, the registry, and nh.
{
  config,
  inputs,
  lib,
  ...
}:
let
  # This checkout, which `nh` rebuilds from: in the home of the one Home
  # Manager user (set in ./default.nix).
  user = builtins.head (builtins.attrNames config.home-manager.users);
  flakeDir = "${config.users.users.${user}.home}/nix_config";
in
{
  nix = {
    settings = {
      extra-experimental-features = [
        "flakes"
        "nix-command"
      ];
      # The working tree is nearly always dirty; the warning carries no signal.
      warn-dirty = false;
      substituters = [
        # cache.nixos.org builds no CUDA; this serves ollama-cuda and its libs.
        "https://cache.nixos-cuda.org"
        # neovim-nightly-overlay builds (danvim) and other nix-community projects.
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      download-buffer-size = 268435456; # 256 MiB
      http-connections = 50;
    };
    # `nixpkgs#` is already pinned; add `nixos#` (alias) and `stable#`.
    registry = {
      nixos.flake = inputs.nixpkgs;
      stable.flake = inputs.stable;
    };
    optimise.automatic = true;
    # No nix.gc: programs.nh.clean below does GC (nh asserts only one is on).

    # Builds yield CPU and disk bandwidth to interactive work.
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };

  programs.nh = {
    enable = true;
    flake = flakeDir;
    clean = {
      enable = true;
      # Not `--delete-old`: after a rebuild that silently missed the ESP it
      # deletes the running kernel's modules. `--keep` >= GRUB's
      # configurationLimit, so GC never removes a generation GRUB lists.
      extraArgs = "--keep-since 3d --keep ${toString (lib.max 10 config.boot.loader.grub.configurationLimit)}";
    };
  };

  # Unpatched binaries find a dynamic loader and the usual libraries.
  programs.nix-ld.enable = true;
}
