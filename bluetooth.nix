{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Source/Sink/Media (A2DP) are enabled by default in modern BlueZ; the old
        # `Enable = "..."` key is audio.conf-era syntax and is rejected by BlueZ 5.86
        # ("Unknown key Enable for group General").
        Experimental = true;
        # Enables the kernel ISO socket, which BAP/LE-Audio needs. Without it
        # bluetoothd logs "bap_adapter_probe() BAP requires ISO Socket which is
        # not enabled" and the BAP plugin fails to probe.
        #
        # History: removed 2026-08-03 to silence "Failed to set default system
        # config for hci0". Restored 2026-08-12 — that message kept firing on
        # EVERY boot with KernelExperimental gone (verified Aug 6/7/7/10/12), so
        # the removal fixed nothing and only cost LE-Audio. The two are
        # unrelated: the hci0 line is a benign BlueZ mgmt warning on adapters
        # that reject some default params. Don't remove this for that reason
        # again.
        KernelExperimental = true;
      };
    };
  };
}
