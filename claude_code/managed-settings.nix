# Claude Code managed settings. A NixOS module, not a home-manager one: on
# Linux Claude Code reads managed settings only from /etc/claude-code (2.1.284
# has no working per-user override), so non_home_manager_config/configuration.nix
# imports this file while ./default.nix stays home-manager.
#
# Managed settings rank above ~/.claude/settings.json and `--settings`, so the
# keys here always track this repo and cannot be overridden from the user file
# or with /statusline. Everything Claude Code changes at runtime (model,
# effort, permissions, theme) stays in the user file, seeded by ./default.nix.
#
# The drop-in is an environment.etc symlink into the store. Claude Code
# accepts symlinked *.json files in managed-settings.d and merges them after
# managed-settings.json in file-name order. It applies to every user on the
# machine; `claude-statusline` is on each home-manager user's PATH.
{ ... }:
{
  environment.etc."claude-code/managed-settings.d/50-dani.json".text = builtins.toJSON {
    # ./statusline-command.nu, installed as `claude-statusline` by ./default.nix.
    statusLine = {
      type = "command";
      command = "claude-statusline";
      refreshInterval = 5;
    };
    # Empty strings drop the Co-Authored-By trailer and the PR line.
    # sessionUrl = false drops the Claude-Session trailer and PR link that
    # Remote Control sessions (remoteControlAtStartup) add otherwise.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
