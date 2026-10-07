{
  config,
  lib,
  theme,
  ...
}:
let
  p = theme.hash;
in
{
  programs.fzf = {
    enable = true;
    # Atuin owns Ctrl-R; this only silences home-manager's conflict warning.
    historyWidget.command = "";
    historyWidget.nushell.command = "";
    # Set here, not appended in zshrc, where the exported variable would gain
    # a copy of the binding per nesting level. Literal `nvim`, not $EDITOR:
    # nushell loads session variables unexpanded.
    defaultOptions = [ "--bind='ctrl-e:execute(nvim {} > /dev/tty)+abort'" ];
    # Colours: FZF_DEFAULT_OPTS_FILE, below.
  };

  # fzf reads this file on every start. A constant path:
  # in FZF_DEFAULT_OPTS itself, a palette switch would not reach fzf until
  # the next login, when session variables are next read.
  my.liveSessionVariables = [
    "FZF_DEFAULT_OPTS"
    "FZF_DEFAULT_OPTS_FILE"
  ];
  home.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${config.xdg.configHome}/fzf/colors";

  # Accent for matches and the pointer, steel for neutral chrome; gold is kept
  # for needs-attention states.
  xdg.configFile."fzf/colors".text =
    "--color="
    + lib.concatStringsSep "," (
      lib.mapAttrsToList (name: value: "${name}:${value}") {
        inherit (p) bg fg border;
        "bg+" = p.surface;
        "fg+" = p.fg;
        hl = p.accent;
        "hl+" = p.accentBright;
        info = p.steel;
        marker = p.accent;
        prompt = p.accent;
        spinner = p.sage;
        pointer = p.accent;
        header = p.olive;
        label = p.steel;
        query = p.fg;
      }
    )
    + "\n";
}
