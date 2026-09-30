# The Firefox start page (Friedrich's *Wanderer above the Sea of Fog* over a
# live dashboard) and the user service that serves it. Served over http, not
# file://, because Vimium can't run on about:newtab and ../vimium.nix excludes
# file:///*. WantedBy=default.target, not graphical-session.target: it needs no
# Wayland, and Hyprland's stop/start of that target would take it down.
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  shared = import ./shared.nix;
  wanderer = pkgs.callPackage ./package.nix { };

  home = config.home.homeDirectory;

  # Resolved here, where $HOME is known. Binaries are store paths: a user
  # unit's PATH is not a login shell's.
  settings = pkgs.writeText "firefox-start-page-wanderer.json" (
    builtins.toJSON {
      inherit (shared)
        port
        weather
        githubUser
        ;
      # services.ollama is configured in non_home_manager_config/ollama.nix.
      ollamaUrl = "http://127.0.0.1:${toString osConfig.services.ollama.port}";
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
      # The page is the new tab: while this is down, Ctrl+T shows an error.
      Restart = "always";
      RestartSec = 3;

      # Cheap hardening. No ProtectHome: the service reads $HOME (worktrees,
      # flake.lock, gh's config and state) and writes the todo file there.
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
