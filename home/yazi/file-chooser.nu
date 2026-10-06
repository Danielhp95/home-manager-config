# Run by xdg-desktop-portal-termfilechooser for every file dialog; arguments
# as in xdg-desktop-portal-termfilechooser(5). Replaces the package's
# yazi-wrapper.sh, whose save flow loses files: the portal writes a
# placeholder holding instructions at the suggested path and only removes it
# from that path on cancel. Move or rename the placeholder, then leave yazi
# without opening it, and the instructions stay behind under the document's
# name while the app is told the save was cancelled.
#
# Here a placeholder that was moved, renamed or copied *is* the answer, however
# yazi was left, and no placeholder of this dialog outlives it.

# Regular files directly inside `dir`, with inodes; empty if it can't be read.
def files-in [dir: string] {
  try { ls -laf $dir | where type == file } catch { [] }
}

# First line of the file yazi wrote its answer to, or null.
def answer [out: string] {
  if ($out | path exists) { open --raw $out | lines | get 0? } else { null }
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
  rm -f $cwd_file

  # What identifies the placeholder wherever it ends up: its inode if it was
  # moved or renamed, its content and age if it was copied or changed disk.
  let placeholder = if $save == "1" and ($path | path type) == "file" {
    ls -l $path | first | insert content (open --raw $path | into binary)
  }

  # Plain `kitty`, not `kitty -1`: this script waits for the window to close.
  # hyprland.lua floats and centres the window by this class; its size is
  # kitty's own, because a floating kitty resizes itself to the size it
  # remembers and so overrides a size rule.
  try {
    (^kitty --class file-chooser
      -o remember_window_size=no
      -o initial_window_width=1200
      -o initial_window_height=800
      yazi $"--chooser-file=($out)" $"--cwd-file=($cwd_file)" $path)
  }

  let cwd = if ($cwd_file | path exists) { open --raw $cwd_file | str trim } else { "" }
  rm -f $cwd_file

  # Choosing a directory: leaving yazi inside one picks it.
  if $directory == "1" and (answer $out) == null and $cwd != "" {
    $"($cwd)\n" | save -f --raw $out
  }

  if $placeholder == null { return }

  # Where the placeholder can have gone: the folder yazi started in, the one
  # it was left in, and that one's subfolders. Anything older than this dialog
  # is never a match, so a save can't land on (or delete) an earlier file.
  let chosen = answer $out
  let origin = $path | path dirname
  let near = if $cwd != "" and ($cwd | path type) == "dir" {
    [$cwd] ++ (try { ls -af $cwd | where type == dir | get name } catch { [] })
  } else { [] }
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
