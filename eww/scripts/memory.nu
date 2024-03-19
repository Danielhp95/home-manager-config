#!/usr/bin/env nu

def main [
  interval : int = 5
] {
  loop {
    let mem = (sys | get mem)
    print ({
      used: ($mem.used | format filesize GB | str replace " " "")
      total: ($mem.total | format filesize GB | str replace " " "")
      percent: (($mem.used / $mem.total) * 100 | into int)
    } | to json -r)
    sleep (echo $interval sec | str join "" | into duration)
  }
}
