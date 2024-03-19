#!/usr/bin/env nu

def parseIwctl [] {
  iwctl station wlan0 show
    | lines
    | skip 5
    | str trim
    | str replace "Connected network" net
    | str replace "IPv4 address" ip
    | parse "{prop} {val}"
}

def select [ val ] {
  where prop == $val | get -i 0.val | default "" | str trim
}

let colors = {
  disconnected: "#988ba2"
  connected: "#cba6f7"
}

def main [ cmd? ] {
  let iwStatus = (parseIwctl)
  if $cmd == toggle {
    if $iwStatus == [] {
      ^rfkill unblock wlan
    } else {
      ^rfkill block wlan
    }
  } else {
    let status = (
      if (($iwStatus | select State) == connected) {
        let ssid = ($iwStatus | select net | str trim);
        let ip = ($iwStatus | select ip | str trim);
        {
          name: $ssid
          color: $colors.connected
          class: "net-connected"
          icon: ""
          status: $"Connected to ($ssid) [($ip)]"
        }
      } else {
        {
          name: "Disconnected."
          color: $colors.disconnected
          class: "net-disconnected"
          icon: "󰖪"
          status: "No WiFi"
        }
      }
    )
    $status | to json
  }
}
