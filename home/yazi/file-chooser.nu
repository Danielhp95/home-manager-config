# Run by xdg-desktop-portal-termfilechooser for every file dialog; arguments
# as in xdg-desktop-portal-termfilechooser(5). Replaces the package's
# yazi-wrapper.sh, whose save flow loses files: the portal writes a
# placeholder holding instructions at the suggested path and only removes it
# from that path on cancel. Move or rename the placeholder, then leave yazi
# without opening it, and the instructions stay behind under the document's
# name while the app is told the save was cancelled.
#
# Here a placeholder that was moved, renamed or copied *is* the answer, however
# yazi was left, and no placeholder of this dialog outlives it. Opening any
# other file asks first: the app writes over whatever a save names, unasked.

# This script, for the window that asks (`main confirm`).
const self = path self

# Regular files directly inside `dir`, with inodes; empty if it can't be read.
def files-in [dir: string] {
  try { ls -laf $dir | where type == file } catch { [] }
}

# The paths yazi wrote as its answer, one per line; none if it was just left.
def answers [out: string] {
  if ($out | path exists) { open --raw $out | lines } else { [] }
}

# Whether `file` holds the placeholder's text and nothing else.
def is-placeholder [file: string, placeholder: any] {
  if $placeholder == null or (ls -l $file | first).size != $placeholder.size { return false }
  (open --raw $file | into binary) == $placeholder.content
}

# A floating kitty of `width` by `height` running `command`; returns when the
# window closes, which is why it is plain `kitty` and not `kitty -1`.
# hyprland.lua floats and centres the window by this class; its size is
# kitty's own, because a floating kitty resizes itself to the size it
# remembers and so overrides a size rule.
def window [width: string, height: string, command: list<string>] {
  try {
    (^kitty --class file-chooser
      -o remember_window_size=no
      -o $"initial_window_width=($width)"
      -o $"initial_window_height=($height)"
      ...$command)
  }
}

# What the window that asks runs: `yes` is created on y, and on no other key.
def "main confirm" [file: string, yes: string] {
  print $"(ansi cursor_off)
  (ansi attr_bold)Overwrite this file?(ansi reset)

  ($file | path basename)
  in ($file | path dirname)

  y  overwrite it
  any other key  back to the files"
  if ((input listen --types [key]).code | str lowercase) == "y" { touch $yes }
}

def main [
  multiple: string
  directory: string
  save: string
  path: string # where to start; for a save, the placeholder
  out: string # one chosen path per line goes here
  debug?: string
] {
  let cwd_file = $"($out).cwd"
  let yes = $"($out).yes"
  rm -f $cwd_file $yes

  # What identifies the placeholder wherever it ends up: its inode if it was
  # moved or renamed, its content and age if it was copied or changed disk.
  let placeholder = if $save == "1" and ($path | path type) == "file" {
    ls -l $path | first | insert content (open --raw $path | into binary)
  }

  # yazi, and again for as long as an overwrite is turned down.
  mut start = $path
  mut left = [] # every folder yazi was left in
  loop {
    window 1200 800 [yazi $"--chooser-file=($out)" $"--cwd-file=($cwd_file)" $start]
    let cwd = if ($cwd_file | path exists) { open --raw $cwd_file | str trim } else { "" }
    rm -f $cwd_file
    if $cwd != "" { $left ++= [$cwd] }

    let chosen = answers $out
    if $save != "1" or ($chosen | is-empty) { break }

    # A save names one file. Enter on a folder names the folder, and the
    # portal then gives up half way: the app gets an error and the placeholder
    # stays where it was, instructions under the document's name. With no
    # answer the portal cancels and removes it.
    if ($chosen | length) > 1 or ($chosen.0 | path expand | path type) != "file" {
      rm -f $out
      break
    }

    # A file that was there before the dialog: ask, and on anything but y go
    # back to yazi with that file under the cursor.
    if (is-placeholder $chosen.0 $placeholder) { break }
    window 72c 12c [$nu.current-exe --no-config-file $self confirm $chosen.0 $yes]
    if ($yes | path exists) {
      rm -f $yes
      break
    }
    rm -f $out
    $start = $chosen.0
  }

  # Choosing a directory: leaving yazi inside one picks it.
  if $directory == "1" and (answers $out | is-empty) and ($left | is-not-empty) {
    $"($left | last)\n" | save -f --raw $out
  }

  if $placeholder == null { return }

  # Where the placeholder can have gone: the folder yazi started in, the ones
  # it was left in, and their subfolders. Anything older than this dialog
  # is never a match, so a save can't land on (or delete) an earlier file.
  let chosen = answers $out | get 0?
  let origin = $path | path dirname
  let near = $left
    | where ($it | path type) == "dir"
    | each {|dir| [$dir] ++ (try { ls -af $dir | where type == dir | get name } catch { [] }) }
    | flatten
  let moved = [$origin] ++ $near
    | uniq
    | each {|dir| files-in $dir }
    | flatten
    | where name != $path and name != $chosen
    | where size == $placeholder.size
    | where inode == $placeholder.inode or modified >= $placeholder.modified
    | where {|f| (open --raw $f.name | into binary) == $placeholder.content }
    | get name

  if $chosen == null and ($moved | length) == 1 {
    # Left without opening anything, but the placeholder was put somewhere:
    # save there. The portal removes the original path if it still exists.
    $"($moved.0)\n" | save -f --raw $out
  } else if ($moved | is-not-empty) {
    # Another file was opened, or it is ambiguous: no instructions stay behind.
    rm -f ...$moved
  }
}
