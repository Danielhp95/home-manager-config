# Connect to a paired bluetooth device. Packaged as `choose-bluetooth-device`
# by ../default.nix, which supplies the shebang, strict mode and PATH.
bluetoothctl power on || true

# U+F293 (nf-fa-bluetooth) as UTF-8 bytes, so the file holds no PUA glyph.
icon=$(printf '\xef\x8a\x93')

# Lines read "<icon> Device <MAC> <name>", so the MAC is field 3.
selection=$(
	bluetoothctl devices Paired |
		sed "s/^/$icon     /" |
		vicinae dmenu -p "Connect to Bluetooth device:"
)
device=$(awk '{print $3}' <<<"$selection")

# vicinae exits 0 even when dismissed; a well-formed MAC is the check.
if [[ ! $device =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
	exit 0
fi

if bluetoothctl connect "$device"; then
	notify-send -a bluetooth "Bluetooth" "Connected to $device"
else
	notify-send -a bluetooth -u critical "Bluetooth" "Failed to connect to $device"
fi
