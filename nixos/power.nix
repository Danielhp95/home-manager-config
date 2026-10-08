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
      # Except the Ethernet card. igc's runtime suspend takes the RTNL, and an
      # ethtool query holds the RTNL while it waits for that suspend to finish:
      # a deadlock that blocks every netlink user. With no cable the card
      # re-suspends 5 s after each query, so a poller hits the window sooner or
      # later. Grayjay's did on 2026-10-07: networking hung, then suspend failed
      # for 48 min with the lid shut (blocked tasks can't freeze) and the
      # battery ran flat. The "+" makes the line `...DENYLIST+=igc`, which TLP
      # appends to its default list instead of replacing it.
      "RUNTIME_PM_DRIVER_DENYLIST+" = "igc";
      USB_AUTOSUSPEND = 1;
    };
  };

  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    # Power off before the cliff: 2% is under a minute at a 150 W load, less
    # than UPower's polling plus a PowerOff can win (2026-10-05 ended in a hard
    # power loss). noctalia's fixed 5% warning fires as this does; its 2% one
    # (the "Life before death" text, home/noctalia/stormlight.nix) never shows.
    percentageAction = 5;
    # Not Hibernate: the 8.8 GB swap partition can't hold a 64 GB RAM image,
    # and no resume device is set.
    criticalPowerAction = "PowerOff";
  };
}
