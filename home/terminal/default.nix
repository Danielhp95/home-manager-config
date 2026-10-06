{
  pkgs,
  config,
  lib,
  ...
}:
let
  p = (import ../../palette).hash;

  # atuin's PTY proxy keeps a shadow vt100, so the Ctrl-R popup draws over the
  # scrollback and restores it. Not atuin's `[pty_proxy] enabled`: that execs
  # from home-manager's late `atuin init` line, so most of .zshrc would run
  # twice. The exec lines are pinned to the store path; PATH isn't set yet.
  atuinPtyProxyZsh = pkgs.runCommand "atuin-pty-proxy-init.zsh" { } ''
    ${lib.getExe config.programs.atuin.package} pty-proxy init zsh > $out
    substituteInPlace $out \
      --replace-fail 'exec atuin pty-proxy' 'exec ${lib.getExe config.programs.atuin.package} pty-proxy'
  '';
in
{
  imports = [
    ./ls-colors.nix
    ./television.nix
    ./nushell.nix
    ./iris.nix
  ];

  # Zoxide hygiene. Literal paths, not $HOME: nushell loads these unexpanded.
  home.sessionVariables = {
    # Skip ~ itself (jumping "home" is trivial), the store, and .git internals
    _ZO_EXCLUDE_DIRS = "${config.home.homeDirectory}:/nix/store/*:*/.git/*";
    # Dedupe symlinked paths before scoring — most things are symlinks on NixOS
    _ZO_RESOLVE_SYMLINKS = "1";
    # fzf reads this file on every start (the colours below). A constant path:
    # in FZF_DEFAULT_OPTS itself, a palette switch would not reach fzf until
    # the next login, when session variables are next read.
    FZF_DEFAULT_OPTS_FILE = "${config.xdg.configHome}/fzf/colors";
  };

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

  home.packages = with pkgs; [
    rsync
  ];
  # Never set TERM globally: inside tmux it must stay tmux-256color, and a forced
  # "kitty" makes nvim send kitty sequences through tmux and corrupt rendering.
  programs = {
    btop = {
      package = pkgs.btop-cuda;
      enable = true;
      settings = {
        shown_boxes = "cpu proc";
        vim_keys = true;
        rounded_corners = true;
        # themes.ember below; btop can't follow the terminal palette.
        color_theme = "ember";
        # The theme's gradients are 24-bit; without this btop quantises them.
        truecolor = true;
      };
      # Gradients run calm -> hot (sage -> gold -> error) where a high reading
      # is bad, and the other way for free/available.
      themes.ember = ''
        theme[main_bg]="${p.bg}"
        theme[main_fg]="${p.fg}"
        theme[title]="${p.accent}"
        theme[hi_fg]="${p.accentBright}"
        theme[selected_bg]="${p.surface}"
        theme[selected_fg]="${p.accentBright}"
        theme[inactive_fg]="${p.muted}"
        theme[graph_text]="${p.fgDim}"
        theme[meter_bg]="${p.border}"
        theme[proc_misc]="${p.olive}"
        theme[cpu_box]="${p.border}"
        theme[mem_box]="${p.border}"
        theme[net_box]="${p.border}"
        theme[proc_box]="${p.border}"
        theme[div_line]="${p.divider}"

        theme[temp_start]="${p.sage}"
        theme[temp_mid]="${p.gold}"
        theme[temp_end]="${p.error}"
        theme[cpu_start]="${p.sage}"
        theme[cpu_mid]="${p.gold}"
        theme[cpu_end]="${p.error}"
        theme[process_start]="${p.sage}"
        theme[process_mid]="${p.gold}"
        theme[process_end]="${p.error}"

        theme[used_start]="${p.sage}"
        theme[used_mid]="${p.gold}"
        theme[used_end]="${p.error}"
        theme[free_start]="${p.error}"
        theme[free_mid]="${p.gold}"
        theme[free_end]="${p.sage}"
        theme[available_start]="${p.error}"
        theme[available_mid]="${p.gold}"
        theme[available_end]="${p.sage}"
        theme[cached_start]="${p.olive}"
        theme[cached_mid]="${p.sage}"
        theme[cached_end]="${p.sageBright}"

        theme[download_start]="${p.olive}"
        theme[download_mid]="${p.sage}"
        theme[download_end]="${p.sageBright}"
        theme[upload_start]="${p.accentDim}"
        theme[upload_mid]="${p.accent}"
        theme[upload_end]="${p.accentBright}"

        theme[followed_bg]="${p.accent}"
        theme[followed_fg]="${p.bg}"
        theme[proc_follow_bg]="${p.accent}"
        theme[proc_pause_bg]="${p.gold}"
        theme[proc_banner_bg]="${p.surface}"
        theme[proc_banner_fg]="${p.fg}"
      '';
    };
    # `btm`. TextStyle keys take a table ({ color, bg_color, bold, italics }),
    # plain *_color keys a bare string; mixing them up fails at startup.
    bottom = {
      enable = true;
      settings.styles = {
        widgets = {
          border_color = p.border;
          selected_border_color = p.accent;
          widget_title.color = p.accent;
          text.color = p.fg;
          selected_text = {
            color = p.bg;
            bg_color = p.accent;
          };
          disabled_text.color = p.muted;
        };
        tables.headers = {
          color = p.gold;
          bold = true;
        };
        graphs = {
          graph_color = p.border;
          legend_text.color = p.fgDim;
        };
        # Cycled per core: a short cool rotation (24 threads make a rainbow
        # unreadable); warm colours are kept for the avg/all lines.
        cpu = {
          all_entry_color = p.accent;
          avg_entry_color = p.accentBright;
          cpu_core_colors = [
            p.sage
            p.olive
            p.steel
            p.mauve
            p.sageBright
            p.oliveBright
          ];
        };
        memory = {
          ram_color = p.accent;
          cache_color = p.olive;
          swap_color = p.gold;
          arc_color = p.sage;
          gpu_colors = [ p.mauve ];
        };
        network = {
          rx_color = p.sage;
          tx_color = p.accent;
          rx_total_color = p.sageBright;
          tx_total_color = p.accentBright;
        };
        # Same ramp direction as btop's: green is fine, red needs attention.
        battery = {
          high_battery_color = p.sage;
          medium_battery_color = p.gold;
          low_battery_color = p.error;
        };
      };
    };
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
    # Really nice shell history
    atuin = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
      enableZshIntegration = true;
      # Socket-activated user service on $XDG_RUNTIME_DIR/atuin.sock. Not
      # settings.daemon.autostart: its $TMPDIR socket let a sandboxed shell with
      # a private /tmp start a second daemon, which stalled every command.
      daemon.enable = true;
      settings = {
        enter_accept = true; # Enter to execute, tab to select
        show_help = false;
        show_tabs = false;
        invert = true;
        ai = {
          enabled = true;
        };
        # Ctrl-R opens filtered to the current git repo (Ctrl-R cycles out).
        workspaces = true;
        # No theme on purpose: atuin's built-in colours beat an Ember one.
      };
    };
    # The proxy runs only for shells sitting directly in a terminal window;
    # tmux panes get plain zsh and drop the proxy variables the server
    # inherited. mkOrder 100: the exec re-reads .zshrc, so anything sourced
    # before it runs twice.
    # Tty guard: a shell on a new tty (nvim's :terminal) must drop a socket
    # owned by another terminal, or Ctrl-R replays that terminal's screen. The
    # TTY variable is cleared before the source so a fresh proxy keeps its own.
    # `source`, not builtins.readFile of a derivation (import-from-derivation).
    zsh.initContent = lib.mkOrder 100 ''
      if [[ -n ''${TMUX:-} ]]; then
        unset ATUIN_PTY_PROXY_ACTIVE ATUIN_PTY_PROXY_TMUX \
          ATUIN_PTY_PROXY_SOCKET ATUIN_PTY_PROXY_TTY
      else
        _atuin_pty_proxy_owner_tty=''${ATUIN_PTY_PROXY_TTY:-}
        unset ATUIN_PTY_PROXY_TTY
        if [[ -n ''${ATUIN_PTY_PROXY_SOCKET:-} && -n $_atuin_pty_proxy_owner_tty \
              && $_atuin_pty_proxy_owner_tty != ''${TTY:-$(tty)} ]]; then
          unset ATUIN_PTY_PROXY_SOCKET
        fi
        unset _atuin_pty_proxy_owner_tty
        source ${atuinPtyProxyZsh}
        export ATUIN_PTY_PROXY_TTY=''${TTY:-$(tty)}
      fi
    '';
    # `ls` replacement
    eza.enable = true;
    # Smart cd (also feeds yazi's builtin z/Z jumps)
    zoxide.enable = true;
    # The one, the fuzzy searcher
    fzf = {
      enable = true;
      # Atuin owns Ctrl-R; this only silences home-manager's conflict warning.
      historyWidget.command = "";
      historyWidget.nushell.command = "";
      # Set here, not appended in zshrc, where the exported variable would gain
      # a copy of the binding per nesting level. Literal `nvim`, not $EDITOR:
      # nushell loads session variables unexpanded.
      defaultOptions = [ "--bind='ctrl-e:execute(nvim {} > /dev/tty)+abort'" ];
      # Colours: FZF_DEFAULT_OPTS_FILE, above.
    };
  };

}
