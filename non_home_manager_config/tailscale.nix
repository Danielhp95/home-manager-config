{ options, ... }:
{
  # Tailscale: WireGuard mesh between your own machines. The daemon only
  # provides the plumbing — enrolling this host in a tailnet is a one-off
  # interactive `sudo tailscale up`; state lives in /var/lib/tailscale and the
  # daemon reconnects by itself on every later boot.
  services.tailscale = {
    enable = true;
    # "client" sets reverse-path filtering to loose, which is what lets replies
    # come back through an exit node. Advertising *this* box as an exit node or
    # subnet router would need "both" (that also turns on IP forwarding).
    useRoutingFeatures = "client";
    # Open 41641/udp so peers can hole-punch a direct connection instead of
    # falling back to relaying everything through Tailscale's DERP servers.
    openFirewall = true;
  };

  # Traffic arriving over the tunnel skips the firewall, so tailnet peers can
  # reach sshd, Taildrop, and anything else listening here. Access is still
  # gated by the tailnet's device list and ACLs — nothing on the LAN or the
  # public internet gains anything from this.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # connman enumerates every interface it sees and would happily try to run
  # DHCP on the tailscale tun device. Entries are matched as prefixes, so
  # "tailscale" covers tailscale0. Appended to the option's default, which
  # any definition here would otherwise replace.
  services.connman.networkInterfaceBlacklist =
    options.services.connman.networkInterfaceBlacklist.default
    ++ [ "tailscale" ];
}
