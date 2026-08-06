{pkgs, lib, ...}:
{
  # systemPackages, not defaultPackages: the latter is the NixOS default set
  # (perl/rsync/strace) and assigning to it removes those from the system.
  environment.systemPackages = with pkgs; [
    impala # iwd TUI. needs conman
    iwgtk # iwd GUI
  ];
  networking.hostName = "fell-omen"; # Define your hostname.

  # NOTE(dani): If things fail, enable this and disable below
  # networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Gotcha: connman soft-blocks (rfkill) any technology whose saved Enable=
  # flag in /var/lib/connman/settings is off, on every boot. A manual
  # `rfkill unblock` powers it back but is NOT persisted — if radios come up
  # blocked again, fix it once with `connmanctl disable/enable <tech>`.
  services.connman.enable = true;
  services.connman.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # mDNS / `.local` resolution. Silences the boot warning
  # "No NSS support for mDNS detected, consider installing nss-mdns!".
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with expliciv per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  # Open ports in the firewall.
  networking.firewall.allowedUDPPorts = [ 53317 ];  # for localsend discovery (multicast)
  networking.firewall.allowedTCPPorts = [ 53317 ];  # for localsend transfer (HTTPS upload)

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
