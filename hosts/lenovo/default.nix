# The ThinkPad T16g Gen 3: what only this machine has (hardware, its boot
# entries, its speakers' EQ) on top of the shared system in ../../nixos.
# The directory name is the host name and the flake's nixosConfigurations attr.
{ hostName, ... }:
{
  imports = [
    ./hardware.nix
    ./roadwarrior.nix # boot entry with the dGPU off
    ./audio-eq # per-device output EQ, as WirePlumber filter-chain sinks
    ../../nixos
  ];

  networking.hostName = hostName;

  # The release this disk was installed with; never bump it.
  system.stateVersion = "26.05";
}
