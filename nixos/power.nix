# Power on a laptop: TLP's policy on AC and on battery, and what UPower does
# when the battery runs out.
_: {
  # TLP instead of power-profiles-daemon (they conflict).
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # Plugged in: full performance
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;

      # On battery: low power
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      CPU_BOOST_ON_BAT = 0;
      PCIE_ASPM_ON_BAT = "powersupersave";
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
    };
  };

  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    # noctalia's last battery warning fires at 2%; any higher pre-empts it.
    percentageAction = 2;
    # Not Hibernate: the 8.8 GB swap partition can't hold a 64 GB RAM image,
    # and no resume device is set.
    criticalPowerAction = "PowerOff";
  };
}
