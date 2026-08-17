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

  # Disable connman's built-in DNS proxy (2026-08-12). By default connman runs a
  # caching resolver on 127.0.0.1:53 + [::1]:53 and writes *those* into
  # resolv.conf instead of the real nameservers. Two problems:
  #
  #   1. It's buggy. 251 dropped replies in the 7 days before this was written
  #      ("Failed to send response N: Bad file descriptor", "Cannot send cached
  #      DNS response"), on every single day. Each drop is a query the client
  #      has to time out and retry.
  #   2. It's a redundant hop. tailscaled owns /etc/resolv.conf and points
  #      everything at 100.100.100.100; its upstream was connman's proxy, which
  #      then forwarded to the router. Three hops for every non-tailnet lookup.
  #
  # With --nodnsproxy connman writes the router's real nameservers, so tailscale
  # forwards straight to them. Drop this flag to get the proxy (and its cache)
  # back. Note this only works out because tailscale learns its upstream by
  # reading whatever connman put in /etc/resolv.conf — see the resolv.conf note
  # below before touching either side.
  services.connman.extraFlags = [ "--nodnsproxy" ];

  # Do NOT "fix" the boot message
  #   connmand: Cannot create /var/run/connman/resolv.conf falling back to /etc/resolv.conf
  # by giving the unit a RuntimeDirectory. The fallback is load-bearing: writing
  # /etc/resolv.conf directly is exactly how tailscaled (direct mode) discovers
  # an upstream resolver before it takes the file over and backs the old one up
  # to /etc/resolv.pre-tailscale-backup.conf. Divert connman's write to
  # /run/connman and tailscale is left with no upstream at all.

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
