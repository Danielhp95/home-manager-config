{ pkgs, inputs, config, ... }:
let
  p = (import ../palette.nix).hash;
in
{
  # Zoxide database hygiene. Literal paths (not $HOME) because the nushell
  # module loads sessionVariables without shell expansion.
  home.sessionVariables = {
    # Skip ~ itself (jumping "home" is trivial), the store, and .git internals
    _ZO_EXCLUDE_DIRS = "${config.home.homeDirectory}:/nix/store/*:*/.git/*";
    # Dedupe symlinked paths before scoring — most things are symlinks on NixOS
    _ZO_RESOLVE_SYMLINKS = "1";
  };

  home.packages = with pkgs; [
    fira-code
    powerline-fonts
    nix-search-tv
    rsync
  ];
  # Do NOT force TERM globally: the terminal emulator sets its own TERM, and inside
  # tmux it must stay tmux-256color. Forcing "kitty" makes nvim emit kitty-specific
  # sequences through tmux, which corrupts rendering (e.g. scrolling one split
  # visually scrolls all windows).
  programs = {
    btop = {
      package = pkgs.btop-cuda;
      enable = true;
      settings = {
        shown_boxes = "cpu proc";
        vim_keys = true;
        rounded_corners = true;
      };
    };
    # Really nice shell history
    atuin = {
      enable = true;
      # package = inputs.stable.legacyPackages.x86_64-linux.atuin;
      flags = [ "--disable-up-arrow" ];
      enableZshIntegration = true;
      settings = {
        enter_accept = true; # Enter to execute, tab to select
        show_help = false;
        show_tabs = false;
        invert = true;
        # search_mode = "daemon-fuzzy";
        daemon = {
          autostart = true;
          enabled = false;
        };
        ai = {
          enabled = true;
        };
      };
    };
    # `ls` replacement
    eza.enable = true;
    # Smart cd (also feeds yazi's builtin z/Z jumps)
    zoxide.enable = true;
    # The one, the fuzzy searcher
    fzf = {
      enable = true;
      # fzf 0.74's bundled nushell integration (shell/completion.nu, emitted by
      # `fzf --nushell` and sourced into config.nu by home-manager) still uses
      # `str downcase`, deprecated in nushell 0.114 — it warns on every nu
      # startup. Patch it to `str lowercase`; drop once upstream fzf is fixed.
      package = pkgs.fzf.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace shell/completion.nu \
            --replace-quiet 'str downcase' 'str lowercase'
        '';
      });
      # Atuin owns Ctrl-R (sourced after fzf); disable fzf's history widget to
      # silence the HM Ctrl-R conflict warning without changing behavior.
      historyWidget.command = "";
      historyWidget.nushell.command = "";
      # Ember colors from palette.nix — coral for match highlights and the
      # pointer, steel for neutral chrome (gold is rationed for
      # needs-attention states, and at 8.4:1 it would outshine the coral)
      colors = {
        bg = p.bg;
        "bg+" = p.surface;
        fg = p.fg;
        "fg+" = p.fg;
        hl = p.accent;
        "hl+" = p.accentBright;
        info = p.steel;
        marker = p.accent;
        prompt = p.accent;
        spinner = p.sage;
        pointer = p.accent;
        header = p.olive;
        border = p.border;
        label = p.steel;
        query = p.fg;
      };
    };
  };

}
