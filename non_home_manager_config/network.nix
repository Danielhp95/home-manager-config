{pkgs, lib, ...}:
{
  environment.defaultPackages = with pkgs; [
    impala # iwd TUI. needs conman
    iwgtk  # iwd GUI
  ];
  networking.hostName = "fell-omen"; # Define your hostname.

  # NOTE(dani): If things fail, enable this and disable below
  # networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  services.connman.enable = true;
  services.connman.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with expliciv per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
