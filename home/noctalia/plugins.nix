# Which plugins run, their settings, and what they need on PATH.
{ config, pkgs, ... }:
let
  # The live checkout: the dart plugin is linked out of it, so the link
  # follows a move of the repo or of this directory.
  flakeDir = "${config.home.homeDirectory}/nix_config";
in
{
  home.packages = [
    # logcli, for `dart logs` (the dart plugin's Logs button).
    pkgs.grafana-loki
    # rylos/tailnet asks `xdg-user-dir DOWNLOAD` for its Taildrop directory.
    pkgs.xdg-user-dirs
  ];

  # The local DART plugin, linked out of the store so edits to ./dart-plugin
  # hot-reload in the running shell without a rebuild.
  xdg.dataFile."noctalia/plugins/dart".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDir}/home/noctalia/dart-plugin";

  programs.noctalia.settings = {
    # No git fetch of the plugin sources at every login (it stalled offline);
    # update from the plugin manager instead.
    plugins.auto_update = "none";
    # Opt-in per id. settings.toml can shadow this whole list, and community
    # plugins must not be updated with a bare `git fetch`:
    # docs/manual-steps.md ("After a switch").
    plugins.enabled = [
      "dani/dart"

      # Keybinds read from the running compositor via hyprctl; plugins that
      # parse hyprland.conf can't read the lua config.
      "kenn/keybind-cheatsheet"

      # Tailscale state, peers (copy IP/name), exit nodes; also a `tn`
      # launcher prefix. Needs tailscale and ssh from the system profile.
      "rylos/tailnet"

      # gpu-screen-recorder front end, no bar widget: Super+Shift+R
      # (hyprland.lua) and the control-center tile drive it.
      "noctalia/screen_recorder"
    ];

    # The recording lands on the clipboard as a file:// URI, which pastes as
    # the file into apps (not into terminals).
    plugin_settings."noctalia/screen_recorder".copy_to_clipboard = true;
  };
}
