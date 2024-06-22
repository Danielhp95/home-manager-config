bluetoothctl power on
bluetoothctl agent on
icon=
device=$(bluetoothctl devices | sed "s/^/$icon/  " | rofi -p "Connect to Bluetooth decive:" -dmenu | awk '{print $3}')
if [ $? -eq 0 ]; then
    # This allows reconnection to a device
    bluetoothctl disconnect
    bluetoothctl connect $device
    if [ $? -eq 0 ]; then
        rofi -e "Great Success! Connected to $device"
    else
        rofi -e "Failed to connect to $device"
    fi
else
    rofi -e "Failed to connect to $device"
fi
