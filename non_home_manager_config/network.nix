{pkgs, lib, ...}:
{
  # systemPackages, not defaultPackages: the latter is the NixOS default set
  # (perl/rsync/strace) and assigning to it removes those from the system.
  environment.systemPackages = with pkgs; [
    impala # iwd TUI. needs conman
    iwgtk # iwd GUI
  ];
  networking.hostName = "fell-omen"; # Define your hostname.

  # Unblock wifi + bluetooth on every boot. systemd-rfkill persists the rfkill
  # state under /var/lib/systemd/rfkill/ and restores it at boot; if it was ever
  # saved "blocked" you'd otherwise need a manual `rfkill unblock wlan bluetooth`
  # after each start. This oneshot clears those soft blocks automatically.
  systemd.services.rfkill-unblock = {
    description = "Unblock wlan and bluetooth via rfkill";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock wlan bluetooth";
    };
  };
  # NOTE(dani): If things fail, enable this and disable below
  # networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

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
  networking.firewall.allowedUDPPorts = [ 53317 ];  # for localsend

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
