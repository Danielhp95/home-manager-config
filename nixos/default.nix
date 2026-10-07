# The system shared by every host: the module list, nixpkgs and its overlay,
# Home Manager, the user. The order of the list is part of the build (it
# orders environment.systemPackages): add new modules at the end.
{
  pkgs,
  inputs,
  theme,
  host,
  ...
}:

let
  # The one account. greeter.nix reads it back from home-manager.users.
  user = "dani";
in
{
  imports = [
    inputs.home-manager.nixosModules.default
    ./claude-code.nix
    ./audio.nix
    ./bluetooth.nix
    ./network.nix
    ./tailscale.nix
    ./ollama.nix
    ./greeter.nix
    ./esp-check.nix
    ./grub-generation-label.nix
    ./fontconfig.nix
    ./nix.nix
    ./power.nix
    ./desktop.nix
    ./locale.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
    inputs.firefox-addons.overlays.default # pkgs.firefox-addons.*
    (import ../pkgs/overlay.nix { inherit inputs theme; })
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs theme host; };
    users.${user} = ../home;
    # Apps overwrite some managed files (mimeapps.list, GTK settings); a stale
    # .backup from an earlier activation would otherwise abort the next one.
    backupFileExtension = "backup";
    overwriteBackup = true;
  };

  # On by default upstream; pinned because it can boot a kernel straight from
  # the store when the one on the ESP is wrong (recovery without a USB stick).
  boot.kexec.enable = true;

  # Compressed in-RAM swap; its higher priority puts it ahead of the LUKS swap.
  zramSwap.enable = true;

  # BBR keeps throughput on lossy/high-latency links; fq is the qdisc it wants.
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    # No swap-in readahead: on zram it decompresses 8 pages per 1-page fault.
    "vm.page-cluster" = 0;
    # Usual for zram: swapping to it beats re-reading dropped page cache.
    "vm.swappiness" = 180;
    # Boosting reclaims early (anti-fragmentation), i.e. swaps under mild load.
    "vm.watermark_boost_factor" = 0;
  };

  # The terminals' ANSI 0-15, so the LUKS prompt and ttys are Ember.
  # Set via kernel params: takes effect on the next boot.
  console.colors = theme.ansi;

  environment.pathsToLink = [
    "/share/zsh"
  ]; # completions of system packages, for Home Manager's zsh

  programs.zsh.enable = true;
  # Home Manager's zsh already runs compinit (with the plugin fpath); a second
  # run here rebuilds ~/.config/zsh/.zcompdump on every shell launch (~1s).
  programs.zsh.enableCompletion = false;
  # LS_COLORS is the palette's (home/terminal/ls-colors.nix); this would replace it
  # with the dircolors default in every interactive shell.
  programs.zsh.enableLsColors = false;
  users.users.${user} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "ydotool" # access to the ydotoold socket (keyboard-driven scrolling)
    ];
    hashedPassword = "$y$j9T$BS53tFZ/aYhulnHaIPdfV1$RgynhBpss3Mkz6Rliz3nn4KsTaQ9RI1mdB8qLb5OdxC";
  };

  # system.stateVersion is per machine: hosts/<host>/default.nix.
}
