{ pkgs, ... }:
let
  # Split tunnel for the SIE VPN, whose gateway pushes a full tunnel: with
  # CISCO_SPLIT_INC set, vpnc-script keeps the LAN default route and sends only
  # corp networks through tun0 (10/8 internal; 162.49/16 SIE, incl. corp DNS).
  # For an unreachable internal host, add its range (and bump CISCO_SPLIT_INC).
  sieVpncSplit = pkgs.writeShellScript "sie-vpnc-split" ''
    export CISCO_SPLIT_INC=2

    export CISCO_SPLIT_INC_0_ADDR=10.0.0.0
    export CISCO_SPLIT_INC_0_MASK=255.0.0.0
    export CISCO_SPLIT_INC_0_MASKLEN=8

    export CISCO_SPLIT_INC_1_ADDR=162.49.0.0
    export CISCO_SPLIT_INC_1_MASK=255.255.0.0
    export CISCO_SPLIT_INC_1_MASKLEN=16

    # Everything is direct by default now, so the SaaS exclude routes are noise.
    unset CISCO_SPLIT_EXC

    # Keep IPv6 off the tunnel, otherwise the v6 default route would still send
    # all dual-stack traffic through the VPN.
    unset CISCO_IPV6_SPLIT_INC INTERNAL_IP6_ADDRESS INTERNAL_IP6_NETMASK

    exec ${pkgs.vpnc-scripts}/bin/vpnc-script "$@"
  '';

  # The GlobalProtect command line the connect scripts below share.
  gpclientCmd = "sudo -E ${pkgs.gpclient}/bin/gpclient";
  connectCmd = "${gpclientCmd} connect --gateway gw15.ggp-ext-gw.sie.sony.com --browser $BROWSER";
  portal = "portal.global-vpn.sie.sony.com --hip";
in
{
  # git comes from programs.git.enable (./git).
  home.packages = with pkgs; [
    awscli2

    gpclient
    # Split tunnel: only corp networks use the VPN (see sieVpncSplit).
    (writeShellScriptBin "sie-vpn-connect" ''
      ${connectCmd} --script ${sieVpncSplit} ${portal}
    '')
    # Original full-tunnel behavior, kept as a fallback.
    (writeShellScriptBin "sie-vpn-connect-full" ''
      ${connectCmd} ${portal}
    '')
    (writeShellScriptBin "sie-vpn-disconnect" ''
      ${gpclientCmd} disconnect
    '')
  ];
}
