# The terminal's tools. Each one with more than a line or two of configuration
# has its own file; the small ones are here.
{
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./ls-colors.nix
    ./television.nix
    ./iris.nix
    ./cli.nix
    ./btop.nix
    ./bottom.nix
    ./atuin.nix
    ./fzf.nix
    ./bat.nix
  ];

  # Zoxide hygiene. Literal paths, not $HOME: nushell loads these unexpanded.
  home.sessionVariables = {
    # Skip ~ itself (jumping "home" is trivial), the store, and .git internals
    _ZO_EXCLUDE_DIRS = "${config.home.homeDirectory}:/nix/store/*:*/.git/*";
    # Dedupe symlinked paths before scoring — most things are symlinks on NixOS
    _ZO_RESOLVE_SYMLINKS = "1";
  };

  home.packages = [ pkgs.rsync ];

  # Never set TERM globally: inside tmux it must stay tmux-256color, and a forced
  # "kitty" makes nvim send kitty sequences through tmux and corrupt rendering.
  programs = {
    # Per-project shells. nix-direnv GC-roots the evaluated shell in .direnv/,
    # so `use flake` is instant on re-entry and survives `nh clean`.
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # tldr client (binary `tldr`); auto-updates keep the page cache fresh.
    tealdeer = {
      enable = true;
      enableAutoUpdates = true;
    };
    # `ls` replacement
    eza.enable = true;
    # Smart cd (also feeds yazi's builtin z/Z jumps)
    zoxide.enable = true;
  };
}
