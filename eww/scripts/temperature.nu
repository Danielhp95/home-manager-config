#!/usr/bin/env nu

def main [
  interval : int = 5
] {
  let secs = (echo $interval sec | str join "" | into duration)
  loop {
    # it appears nushell can't handle NaN properly outside of dataframes
    let temps = (sys | get temp.temp | dfr into-df  | dfr fill-nan (-1) | dfr into-nu | get "0")
    # let temps = (sys | get temp.temp)
    let avg = ($temps | math avg)
    print ({
      max: ($temps | math max)
      min: ($temps | math min)
      median: ($temps | math median)
      mode: ($temps | math mode | get 0)
      avg: ($avg)
      percent: (($avg / 80) * 100 | into int)
    } | to json -r)
    sleep $secs
  }
}
