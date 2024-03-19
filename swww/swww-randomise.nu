#!/usr/bin/env nu

def findImages [ ] {
  path expand
  | each { |directory|
    fd -e png -e jpg . $directory
    | lines
  }
  | flatten
}

# expects $images
def checkLength [
  directories # only used for error message
] {
  let length = ($in | length)
  if $length == 0 {
    print $"(ansi red)No images found in directories provided:(ansi reset)" $directories
    exit 1
  }
  $length
}

# starts a never-ending process that cycles through images in a sends them
# to swww at a specific time interval
#
# if interval is 0, then don't loop
# i.e. `swww_randomise -i 0 ~/mypics`
def main [
  --interval(-i) : int  # time interval between switching images (60s default)
  --step(-s)     : int  # ? : corresponds to SWWW_TRANSITION_FPS
  --fps(-f)      : int  # ? : corresponds to SWWW_TRANSITION_STEP
  --noShuffle           # toggle to disable automatic shuffle of all images
  ...directories        # directories to search for images
] {
  print $"(ansi green)Starting swww.(ansi reset)"
  $env.SWWW_TRANSITION_FPS = ($fps | default ($env | get -i SWWW_TRANSITION_FPS | default 60))
  $env.SWWW_TRANSITION_STEP = ($step | default ($env | get -i SWWW_TRANSITION_STEP | default 2))
  let interval = ($interval | default 60)
  print $"Searching directories: (ansi yellow)($directories)(ansi reset)"
  mut images = ($directories | findImages)
  mut length = ($images | checkLength $directories)
  if not $noShuffle {
    $images = ($images | shuffle)
  }
  if $interval <= 0 {
    swww img ($images | first)
    exit 0
  }
  mut i = 0
  print $"Starting loop of ($length) images."
  loop {
    if $i < $length {
      let image = ($images | get $i)
      swww img $image --transition-type center
      $i = $i + 1
      sleep (echo $interval sec | str join "" | into duration)
    } else {
      $images = ($directories | findImages)
      $length = ($images | checkLength $directories)
      $i = 0
    }
  }
  print $"Stopping swww."
}
