{ options, ... }:
{
  # Enrolment is a one-off `sudo tailscale up`; state is in /var/lib/tailscale.
  services.tailscale = {
    enable = true;
    # Loose reverse-path filtering, so replies through an exit node get in.
    # Serving as an exit node or subnet router would need "both".
    useRoutingFeatures = "client";
    # 41641/udp, so peers connect directly instead of through DERP relays.
    openFirewall = true;
  };

  # Tunnel traffic skips the firewall (sshd, Taildrop, ...); access is still
  # gated by the tailnet's device list and ACLs.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Stops connman running DHCP on tailscale0 (entries are prefixes). Appended
  # to the option's default, which a plain definition would replace.
  services.connman.networkInterfaceBlacklist =
    options.services.connman.networkInterfaceBlacklist.default
    ++ [ "tailscale" ];
}
