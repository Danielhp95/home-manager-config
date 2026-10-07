# yazi's key bindings, ahead of its preset (mgr.prepend_keymap). One line each:
# the chord (keys separated by spaces), the action, and the label the which-key
# menu shows.
{ lib }:
let
  key = on: run: desc: {
    on = lib.splitString " " on;
    inherit run desc;
  };
in
[
  (key "g c" "plugin vcs-files" "Show Git file changes")
  (key "<c-f>" "plugin tv" "Jump to a file via television")
  (key "<c-d>" "plugin tv dirs" "Jump to a directory via television")
  (key "<C-g>" "plugin tv text" "Open files using neovim and jump to where the string is located")
  # Every mount action lives under M (a which-key menu), the only free
  # prefix in yazi's preset keymap: M m is mount.yazi's udisks UI, M p the
  # GVfs devices. The menu lists candidates in binding order.
  (key "M m" "plugin mount" "Mount disks/partitions (udisks)")
  (key "M p" "plugin gvfs -- select-then-mount --jump" "Mount phone/device (MTP) and jump to it")
  (key "M j" "plugin gvfs -- jump-to-device" "Jump to a mounted device")
  (key "M b" "plugin gvfs -- jump-back-prev-cwd" "Back to where you were before the device")
  (key "M u" "plugin gvfs -- select-then-unmount --eject" "Unmount/eject device")
  (key "M U" "plugin gvfs -- select-then-unmount --eject --force" "Force unmount/eject device")
  (key "M a" "plugin gvfs -- add-mount" "Add a GVfs mount URI (smb, sftp, ftp, ...)")
  (key "M e" "plugin gvfs -- edit-mount" "Edit a GVfs mount URI")
  (key "M r" "plugin gvfs -- remove-mount" "Remove a GVfs mount URI")
  (key "<c-h>" "help" "show help")
  (key "c c" "shell --block $SHELL" "open shell here")
  (key "m p" "plugin toggle-pane min-preview" "hide or show preview")
  (key "m P" "plugin toggle-pane max-preview" "max preview")
  (key "+" "plugin zoom 1" "Zoom in hovered file")
  (key "-" "plugin zoom -1" "Zoom out hovered file")
  (key "l" "plugin smart-enter" "Enter dir / open file with one key")
  (key "c m" "plugin chmod" "Chmod selected files")
  (key "c a" "plugin compress" "Archive selected files")
  # Move to sibling dir of the parent without leaving cwd
  (key "K" "plugin parent-arrow -1" "Parent dir up")
  (key "J" "plugin parent-arrow 1" "Parent dir down")
  # Trash restore (needs trash-cli)
  (key "d u" "plugin restore" "Restore last deleted files/folders")
  # Bookmarks (yamb)
  (key "u a" "plugin yamb -- save" "Add bookmark")
  (key "u g" "plugin yamb -- jump_by_key" "Jump bookmark by key")
  (key "u G" "plugin yamb -- jump_by_fzf" "Jump bookmark by fzf")
  (key "u d" "plugin yamb -- delete_by_key" "Delete bookmark by key")
  (key "u A" "plugin yamb -- delete_all" "Delete all bookmarks")
]
