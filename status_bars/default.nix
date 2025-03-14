{pkgs, lib, home, inputs, stableWithUnfree, ...}:
{
  home.packages = with pkgs; [
    inputs.unstable.legacyPackages.x86_64-linux.i3bar-river
    inputs.unstable.legacyPackages.x86_64-linux.i3status-rust
  ];

  home.file.".config/i3bar-river/config.toml".text = ''
    # The status generator command.
    # Optional: with no status generator the bar will display only tags and layout name.
    command = "i3status-rs"
  '';
  home.file.".config/i3status-rust/config.toml".text = ''
[theme]
theme = "slick"

[[block]]
block = "net"
format = " $icon {$signal_strength $ssid $frequency|Wired connection} via $device "

[[block]]
block = "music"

[[block]]
block = "disk_space"
info_type = "available"
alert_unit = "GB"
alert = 10.0
warning = 15.0
format = " $icon $available "
format_alt = " $icon $available / $total "

[[block]]
block = "memory"
format = " $icon $mem_used_percents.eng(w:1) "
format_alt = " $icon_swap $swap_free.eng(w:3,u:B,p:Mi)/$swap_total.eng(w:3,u:B,p:Mi)($swap_used_percents.eng(w:2)) "
interval = 30
warning_mem = 70
critical_mem = 90

[[block]]
block = "cpu"
interval = 1

[[block]]
block = "time"
interval = 60
[block.format]
short = " $icon $timestamp.datetime(f:%R) "

[[block]]
block = "battery"

[[block]]
block = "bluetooth"
mac = "14:3F:A6:58:C8:61"
format = "Headphones Connected"
'';
}
