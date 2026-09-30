{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # No `Enable = "Source,Sink,..."`: A2DP is on by default and BlueZ
        # rejects that old key.
        Experimental = true;
        # The kernel ISO socket BAP/LE Audio needs. Unrelated to the benign
        # "Failed to set default system config for hci0" boot warning; don't
        # drop it to silence that.
        KernelExperimental = true;
      };
    };
  };
}
