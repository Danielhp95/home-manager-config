{ inputs, lib, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile ./kitty.conf;
    # themeFile = "Dracula";
  };

  # kitty runs single-instance (`kitty -1` in hyprland.lua), so new windows
  # reuse the long-lived process and never re-read kitty.conf on their own.
  # SIGUSR1 tells the running instance to reload its config, which follows the
  # ~/.config/kitty/kitty.conf symlink to the freshly-switched store path —
  # so every `nh os switch` applies config changes to open terminals too.
  # (A kitty *binary* upgrade still needs all kitty windows closed once.)
  home.activation.reloadKitty = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.procps}/bin/pkill -USR1 -x kitty || true
  '';
}
