{pkgs, ...}:
{
  networking.hostName = "fell-omen";
  # networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  # networking.networkmanager.wifi.backend = "iwd";

  environment.defaultPackages = with pkgs; [
    impala # iwd TUI
    iwgtk  # iwd GUI
  ];
  networking.wireless.iwd.enable = true;
  networking.wireless.iwd.settings = {
    IPv6 = {
      Enabled = true;
    };
    Settings = {
      AutoConnect = true;
    };
  };
}
