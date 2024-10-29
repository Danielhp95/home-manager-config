bluetoothctl power on
bluetoothctl agent on
icon=
rofi_output=$(bluetoothctl devices | sed "s/^/$icon     /" | rofi -no-custom -p "Connect to Bluetooth decive:" -dmenu)
rofi_output_signal=$?
device=$(echo $rofi_output | awk '{print $3}')
if [ $rofi_output_signal -eq 0 ]; then
    # bluetoothctl disconnect
    bluetoothctl connect $device
    if [ $? -eq 0 ]; then
        rofi -e "Great Success! Connected to $device"
    else
        rofi -e "Failed to connect to $device"
    fi
fi
