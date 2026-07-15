{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    gh
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
    wezterm = {
      enable = true;
      extraConfig = builtins.readFile ./wezterm.lua;
      enableZshIntegration = false;
    };
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
      # Ember theme colors
      colors = {
        bg = "#1c1b19";
        "bg+" = "#2c2b29";
        fg = "#d8d0c0";
        "fg+" = "#d8d0c0";
        hl = "#e08060";      # coral - highlights
        "hl+" = "#e08060";   # coral - current line highlight
        info = "#c8b468";    # gold - info text
        marker = "#e08060";  # coral - markers
        prompt = "#c09058";  # orange - prompt (changed from steel)
        spinner = "#80a090"; # sage - spinner
        pointer = "#e08060"; # coral - pointer
        header = "#8a9868";  # olive - header
        border = "#3c3b39";  # bg2 - border
        label = "#c8b468";   # gold - labels
        query = "#d8d0c0";   # fg0 - query text
      };
    };
  };

}
