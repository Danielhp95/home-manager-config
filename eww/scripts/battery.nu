#!/usr/bin/env nu

let icons = [ "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" ]
let iconLength = ($icons | length)
let red = '#f38ba8'
let green = '#a6e3a1'

def getBatteryLabel [] {
  upower -e | rg BAT | str trim
}

# {"icon": "󰂂", "percentage": , "wattage": "", "status": " left", "color": "#a6e3a1"}

def getStatus [ info ] {
  if ($info | get -i time_to_empty) != null {
    $"($info.time_to_empty) ($info.time_to_empty_unit) left"
  } else if ($info | get -i time_to_full) != null {
    $"($info.time_to_full) ($info.time_to_full_unit) left"
  } else {
    "Unknown Status."
  }
}

let $bat = (getBatteryLabel)
def generate [] {
  let info = (upower -i $bat | jc --upower | from json | get detail)
  if $info == [] {
    return ({
      icon: "⁉"
      percentage: 0
      wattage: "0 W"
      status: "no battery detected"
    } | to json -r)
  }
  let $info = ($info.0)
  let iconIndex = (($info.percentage * $iconLength / 100) | math round)
  let percentage = ($info.percentage | into int)
  let wattage = $"($info.energy_rate) ($info.energy_rate_unit)"
  let status = (getStatus $info)
  let color = (if $percentage < 20 { $red } else { $green })
  {
    icon: ($icons | get $iconIndex)
    percentage: $percentage
    wattage: $wattage
    status: $status
    color: $color
  } | to json -r
}

generate | print
upower -m
  | rg --line-buffered $bat
  | lines
  | each {|it|
    generate | print
  }
