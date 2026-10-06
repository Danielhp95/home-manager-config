# Claude Code managed settings. A NixOS module: on Linux they are only read
# from /etc/claude-code (symlinked drop-ins are fine). They outrank the user
# file, which keeps the runtime-owned keys (seeded by ../home/claude-code/default.nix), and
# apply to every user on the machine.
{ ... }:
{
  environment.etc."claude-code/managed-settings.d/50-dani.json".text = builtins.toJSON {
    # ../home/claude-code/statusline-command.nu, installed as `claude-statusline` by ../home/claude-code/default.nix.
    statusLine = {
      type = "command";
      command = "claude-statusline";
      refreshInterval = 5;
    };
    # No Co-Authored-By trailer or PR line; sessionUrl = false also drops the
    # Claude-Session trailer that Remote Control sessions add.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
