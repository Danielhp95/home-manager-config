{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  pathToSaiRepo = "$HOME/Projects/sai";

  # Split-tunnel vpnc-script for the SIE VPN.
  #
  # The gateway is full-tunnel by design: it pushes a default route through the
  # VPN plus a long list of "split-exclude" SaaS ranges (Teams/Zoom/etc.) that go
  # direct. openconnect's vpnc-script only skips installing the default route when
  # CISCO_SPLIT_INC is set, so here we inject it to flip the model: keep the normal
  # default route on the LAN, and send ONLY corporate networks through tun0.
  #
  #   10.0.0.0/8      -- corp internal (our tunnel IP is 10.94.x)
  #   162.49.0.0/16   -- Sony/SIE space (corp DNS 162.49.100.253/254 + internal web)
  #
  # If an internal host turns out unreachable, find its IP range and add another
  # CISCO_SPLIT_INC_N_ entry below (bump CISCO_SPLIT_INC accordingly).
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
in
{
  # Salt minion: services.salt.minion.enable is a NixOS (system) option, so it
  # lives in ../non_home_manager_config/salt.nix, imported from flake.nix.

  home.packages = with pkgs; [
    git
    awscli2
    amazon-ecr-credential-helper

    docker
    cudaPackages.cudatoolkit

    steam-run # To run proton via Steam's FHS

    gpclient
    # Split tunnel: only corp networks go through the VPN (see sieVpncSplit above).
    (writeShellScriptBin "sie-vpn-connect" ''
      sudo -E ${pkgs.gpclient}/bin/gpclient connect --gateway gw15.ggp-ext-gw.sie.sony.com --browser $BROWSER --script ${sieVpncSplit} portal.global-vpn.sie.sony.com --hip
    '')
    # Original full-tunnel behavior, kept as a fallback.
    (writeShellScriptBin "sie-vpn-connect-full" ''
      sudo -E ${pkgs.gpclient}/bin/gpclient connect --gateway gw15.ggp-ext-gw.sie.sony.com --browser $BROWSER portal.global-vpn.sie.sony.com --hip
    '')
    (writeShellScriptBin "sie-vpn-disconnect" ''
      sudo -E ${pkgs.gpclient}/bin/gpclient disconnect
    '')

    # gtc demo
    goose-cli
    libxcb-cursor

  ];

  # Ensure that credentials are stored in `.netrc`
  # home.file.".config/pip/pip.conf".source = ./pip.conf;
  # home.file.".config/pypoetry/auth.toml".source = ./poetry_auth.toml;

  home.file.".docker/config.json".source = ./docker_config.json;
  home.file.".config/sai_docker/config.yaml".source = ./sai_docker_config.yaml;

  # environment.etc."fixuid/config.yml".source = ./fixuid_config.yml
  # home.activation.cloneRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   if [ ! -d "${pathToSaiRepo}" ]; then
  #     ${pkgs.git}/bin/git clone https://github.com/user/repo.git ${pathToSaiRepo}
  #   fi
  # '';
}
