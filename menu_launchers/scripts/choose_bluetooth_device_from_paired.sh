# Connect to an already-paired bluetooth device. Packaged as
# `choose-bluetooth-device` by ../default.nix (writeShellApplication supplies
# the shebang, strict mode and PATH).
bluetoothctl power on || true

# U+F293, nf-fa-bluetooth, written as UTF-8 bytes so the file holds no
# private-use glyph.
icon=$(printf '\xef\x8a\x93')

# `bluetoothctl devices Paired` prints "Device <MAC> <name>", so the icon
# prefix pushes the MAC out to field 3.
selection=$(
	bluetoothctl devices Paired |
		sed "s/^/$icon     /" |
		vicinae dmenu -p "Connect to Bluetooth device:"
)
device=$(awk '{print $3}' <<<"$selection")

# vicinae can't guarantee the result is a real list entry, and it exits 0 when
# dismissed, so the MAC itself is the check.
if [[ ! $device =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
	exit 0
fi

# Toasts: noctalia is the notification daemon, so these are Ember-themed, land
# in notification history, and do not need dismissing.
if bluetoothctl connect "$device"; then
	notify-send -a bluetooth "Bluetooth" "Connected to $device"
else
	notify-send -a bluetooth -u critical "Bluetooth" "Failed to connect to $device"
fi
