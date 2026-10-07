# yazi as the desktop's file manager: what "Show in folder" and "Open folder"
# in an app reach.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.home.sessionVariables) TERMINAL;

  # yazi in a window of its own.
  yazi = "${TERMINAL} -e yazi";

  fileManager1 = pkgs.writers.writePython3 "file-manager1" {
    libraries = [ pkgs.python3Packages.dbus-fast ];
    # dbus-fast reads a method's D-Bus signature from its annotations
    # ("as", "s"), which flake8 takes for undefined names.
    flakeIgnore = [
      "F821"
      "F722"
    ];
  } (builtins.readFile ./file-manager1.py);
in
{
  xdg = {
    # "Show in folder": the app asks whoever owns org.freedesktop.FileManager1
    # to show a file, and yazi given a file opens its folder with the file under
    # the cursor. Nautilus ships a service file for the same name; this one is
    # read first, being in ~/.local/share. The window is a unit of its own
    # (systemd-run) so that it outlives the service, which D-Bus starts per call.
    dataFile."dbus-1/services/org.freedesktop.FileManager1.service" = {
      text = ''
        [D-BUS Service]
        Name=org.freedesktop.FileManager1
        Exec=${fileManager1} systemd-run --user --collect --quiet -- ${yazi}
      '';
      # The session bus reads its service files when told to, not when they
      # change. Its socket is under XDG_RUNTIME_DIR, which the activation
      # service does not have set.
      onChange = ''
        XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
          ${lib.getExe' pkgs.systemd "busctl"} --user call org.freedesktop.DBus \
          /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
      '';
    };

    # "Open folder", and xdg-open on a directory. In place of the entry yazi
    # ships, which says Terminal=true and so starts nothing from an app (see
    # nvim's in ../default-applications.nix). Left to themselves, folders went
    # to `kitty +open`: a shell in the folder.
    desktopEntries.yazi = {
      name = "Yazi File Manager";
      genericName = "File Manager";
      exec = "${yazi} %f";
      icon = "yazi";
      categories = [
        "Utility"
        "System"
        "FileTools"
        "FileManager"
      ];
      mimeType = [ "inode/directory" ];
    };
    mimeApps.defaultApplications."inode/directory" = [ "yazi.desktop" ];
  };
}
