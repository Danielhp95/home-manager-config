# Clicking a notification focuses the app it came from. Noctalia leaves that to
# the app and most apps fail at it; notification-focus.nu says why and how this
# does it for them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  watcher = pkgs.writers.writeNu "noctalia-notification-focus" (
    builtins.readFile ./notification-focus.nu
  );
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.finalPackage "hyprctl";
in
{
  systemd.user.services.noctalia-notification-focus = {
    Unit = {
      Description = "Focus the app whose notification was clicked";
      # With the session, not with noctalia: hyprctl finds the compositor
      # through the environment the session exports, and the bus match follows
      # whoever owns the notification name.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watcher} ${pkgs.systemd}/bin/busctl ${hyprctl}";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
