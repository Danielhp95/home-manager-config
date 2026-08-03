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
        # KernelExperimental (BlueZ ISO socket for BAP/LE-Audio) removed
        # 2026-08-03: the adapter rejected the resulting config on every boot
        # ("Failed to set default system config for hci0"). Re-add if LE-Audio
        # is ever needed.
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
