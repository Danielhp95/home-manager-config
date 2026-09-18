# The Firefox start page: Friedrich's *Wanderer above the Sea of Fog* with a
# live dashboard on it, at http://127.0.0.1:47818/.
#
# Three pieces, one per file:
#   ./shared.nix   port, URL, search aliases, paths — the values ../default.nix
#                  and ../vimium.nix also need, spelled once
#   ./package.nix  the built page (./page) and the backend (./service)
#   ./art.nix      the painting, fetched by hash and Ember-graded
#
# ../default.nix does the Firefox half: the New Tab Override add-on pointed at
# this URL, and browser.startup.homepage.
#
# Why a service at all, rather than a file:// page: Vimium does not run on
# Firefox's own about:newtab, and file:///* is excluded in ../vimium.nix — so
# the page has to be served over http to be usable from the keyboard. Since
# something has to serve it, it may as well answer with live data.
#
# WantedBy=default.target, deliberately not graphical-session.target: the
# backend needs no Wayland, and hyprland's extraCommands stop/start of that
# target takes PartOf= units down with it.
{ config, pkgs, ... }:

let
  shared = import ./shared.nix;
  wanderer = pkgs.callPackage ./package.nix { };

  home = config.home.homeDirectory;

  # Everything the service needs to know, resolved here where $HOME is known.
  # Binaries are absolute store paths because a systemd user unit's PATH is
  # not a login shell's.
  settings = pkgs.writeText "firefox-start-page-wanderer.json" (
    builtins.toJSON {
      inherit (shared)
        port
        weather
        githubUser
        ollamaUrl
        ;
      pageDir = "${wanderer.page}";
      nixConfigDir = "${home}/${shared.nixConfigDir}";
      repos = map (repo: "${home}/${repo}") shared.repos;
      todoFile = "${home}/${shared.todoFile}";
      gitBin = "${pkgs.git}/bin/git";
      ghBin = "${pkgs.gh}/bin/gh";
    }
  );
in
{
  systemd.user.services.firefox-start-page-wanderer = {
    Unit = {
      Description = "Firefox start page (Wanderer above the Sea of Fog) and its live-data backend";
    };

    Service = {
      ExecStart = "${wanderer.service}/bin/firefox-start-page-wanderer ${settings}";
      # The page *is* the new tab: if this dies, Ctrl+T shows a connection
      # error, so it comes back rather than staying down.
      Restart = "always";
      RestartSec = 3;

      # Cheap hardening only. ProtectHome is deliberately *not* set: the
      # service's whole job is reading $HOME (git worktrees, flake.lock,
      # ~/.config/gh) and writing one file in it, and `gh` also wants a state
      # directory of its own. ProtectSystem=strict still keeps it out of /usr,
      # /boot and /etc, and it runs as the user anyway, so it can already
      # reach nothing the user cannot.
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictRealtime = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
