#!/usr/bin/env nu

let colors = [ "#f38ba8" "#fab387" "#a6e3a1" "#89b4fa" ]
let empty = "#313244"

def isHyprland [] {
  ($env | get -i HYPRLAND_INSTANCE_SIGNATURE) != null
}

def isSway [] {
  ($env | get -i SWAYSOCK) != null
}

def getFocusHyprland [] {
  hyprctl -j monitors | from json | where focused == true | get activeWorkspace.id.0 | into int
}

def getFocusSway [] {
  swaymsg -t get_outputs -r | from json | get current_workspace.0 | into int
}

def getWorkspacesSway [] {
  swaymsg -t get_tree
  | from json
  | get nodes.nodes
  | flatten
  | filter {|it| ($it | get -i num) != null }
  | rename --column {
    num: id
    id: node_id
  }
}

def getWorkspaces [] {
  hyprctl -j workspaces
  | from json
  | where id > 0
}

def getWorkspace [ id : int ] {
  getWorkspaces | where id == $id
}

def genInitialHyprland [] {
  1..9
  | each {|i| wrap id}
  | join (getWorkspaces) id --left
}

def genInitialSway [] {
  1..9
  | each {|i| wrap id}
  | join (getWorkspacesSway) id --left
}

if (isSway) {
  $env.focusedws = (getFocusSway)
  $env.workspaces = (genInitialSway)
} else {
  $env.focusedws = (getFocusHyprland)
  $env.workspaces = (genInitialHyprland)
}

def getMonitors [] {
  hyprctl -j monitors
  | from json
  | where id > 0
  | select name id
}

def applist [ workspace ] {
  let apps = (
    hyprctl -j clients
    | from json
    | where workspace.id == $workspace
    | select title
  )
  $apps | get title | str join " || "
}

let screencast = false
def generate [] {
  let workspacesJsonList = ($env.workspaces | each {|ws|
    let isActive = (($ws | get -i name) != null)
    # let isFocused = ((($workspace | get -i focused) != null) and $workspace.focused)
    let isFocused = ($env.focusedws == $ws.id)
    {
      number: $ws.id
      active: $isActive
      color: (if $isFocused { "#f38ba8" } else if $isActive { "#fab387" } else { $empty })
      focused: $isFocused
      tooltip: (if (isSway) { $ws.representation } else { applist $ws.id })
    }
  })
  { workspaces: $workspacesJsonList
    screencast: ($screencast)
    isHyprland: (isHyprland)
    isSway: (isSway)
    title: ($workspacesJsonList | where focused == true | get -i 0.tooltip | default "")
  } | to json -r
}

def main [] {
  # initial generation
  (generate | print)

  if (isSway) {

    # expect sway
    swaymsg -mt subscribe '["workspace"]'
      | lines
      | each {|event|
        # let parsed = ($event | from json)
        # match $parsed.change {
        #   "focus" | "init" => {
        #     $env.focusedws = $parsed.current.num
        #   },
        # }
        $env.focusedws = (getFocusSway)
        $env.workspaces = (genInitialSway)
        generate | print
      }

  } else {
    # listen and print new workspaces
    socat -u $"UNIX-CONNECT:/tmp/hypr/($env.HYPRLAND_INSTANCE_SIGNATURE)/.socket2.sock" -
      | rg --line-buffered "workspace|mon(itor)?|screencast"
      | lines
      | each {|it|
        let parsed = ($it | parse "{command}>>{num}" | get 0)
        let num = ($parsed.num | into int)
        # still having issues with this
        # match $parsed.command {
        #   "workspace" => {
        #     $env.focusedws = (getFocusHyprland)
        #   },
        #   "createworkspace" => {
        #     $env.workspaces = (genInitialHyprland)
        #     $env.focusedws = (getFocusHyprland)
        #     # $env.workspaces = ($env.workspaces | each {|w| if $w.id == $num {
        #     #   let ws = (getWorkspace $num)
        #     #   if $ws != [] { $ws.0 } else { $w }
        #     # } else { $w }})
        #   },
        #   "destroyworkspace" => {
        #     $env.workspaces = (genInitialHyprland)
        #     $env.focusedws = (getFocusHyprland)
        #     # $env.workspaces = ($env.workspaces | each {|w| if $w.id == $num { { id: $num } } else { $w }})
        #   },
        # }
        $env.workspaces = (genInitialHyprland)
        $env.focusedws = (getFocusHyprland)
        generate | print
      }

  }
}
