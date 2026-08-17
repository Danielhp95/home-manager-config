{ pkgs, ... }:
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

  # Fix D-Bus permissions for WirePlumber <-> BlueZ communication
  services.dbus.packages = with pkgs; [
    bluez
    (writeTextFile {
      name = "wireplumber-bluez-dbus-policy";
      destination = "/share/dbus-1/system.d/wireplumber-bluez.conf";
      text = ''
        <!DOCTYPE busconfig PUBLIC
         "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
         "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
          <policy user="root">
            <allow send_destination="org.bluez"/>
          </policy>
          <policy context="default">
            <allow send_destination="org.bluez"
                   send_interface="org.freedesktop.DBus.ObjectManager"/>
            <allow send_destination="org.bluez"
                   send_interface="org.freedesktop.DBus.Properties"/>
            <allow send_destination="org.bluez"
                   send_interface="org.bluez.Adapter1"/>
            <allow send_destination="org.bluez"
                   send_interface="org.bluez.Device1"/>
            <allow send_destination="org.bluez"
                   send_interface="org.bluez.MediaControl1"/>
            <allow send_destination="org.bluez"
                   send_interface="org.bluez.MediaPlayer1"/>
          </policy>
        </busconfig>
      '';
    })
  ];
}
