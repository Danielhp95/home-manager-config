{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  p = (import ../palette.nix).hash;

  # Atuin's PTY proxy — the feature that shipped as `atuin hex` in v18.13 and
  # was renamed to `atuin pty-proxy` before this version. It is a minimal
  # tmux-alike: it proxies bytes between the terminal and the shell while
  # keeping a shadow vt100, which is what lets the Ctrl-R popup draw *over*
  # your previous output and then restore it. Without it atuin has to pick
  # between clearing the scrollback (inline) or taking the whole screen (alt
  # screen); inline_height = 40 above is the setting that trade-off comes from.
  #
  # There is no config.toml switch for it — activation is purely this shell
  # snippet, which `exec`s the proxy and lets it respawn zsh underneath.
  #
  # Generated at build time rather than `eval "$(atuin pty-proxy init zsh)"`,
  # for the same reason the IRIS hook in iris.nix is inlined: that eval is a
  # subprocess on every single interactive zsh start. The cost of pinning it
  # is that upstream changes to the snippet only land on rebuild — which is
  # what we want, since a silent upstream change to an `exec` line in .zshrc
  # is exactly the kind of thing that should be reviewed, not absorbed.
  #
  # The sed pins `atuin` to the store path. The snippet runs at the very top
  # of .zshrc, before anything here has touched PATH, so a bare `atuin` would
  # depend on the login environment having already exported it.
  atuinPtyProxyZsh = pkgs.runCommand "atuin-pty-proxy-init.zsh" { } ''
    ${config.programs.atuin.package}/bin/atuin pty-proxy init zsh > $out
    sed -i 's|exec atuin pty-proxy|exec ${config.programs.atuin.package}/bin/atuin pty-proxy|g' $out
  '';
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
        # Selects themes/ember.theme below. btop ships ~40 themes but has no
        # notion of "follow the terminal palette" — without this it draws its
        # built-in Default (green/cyan gradients), which is the one full-screen
        # TUI here that looked like a different machine.
        color_theme = "ember";
        # The gradients are 24-bit hex, so truecolor has to stay on for them to
        # land; btop would otherwise quantise them to the 256-colour cube.
        truecolor = true;
      };
      # Written to $XDG_CONFIG_HOME/btop/themes/ember.theme.
      #
      # btop's *_start/_mid/_end triples are three-stop gradients, and their
      # direction carries meaning: temp/cpu/used/process ramp calm -> hot
      # (sage -> gold -> error) because a high reading is bad, while
      # free/available run the other way because a high reading is good. gold
      # sits in the middle of every ramp, which is the "needs attention"
      # role it already has in the fzf colors above.
      #
      # The mem and net gradients are defined for completeness but are not
      # visible under `shown_boxes = "cpu proc"` — they only appear if the
      # boxes are toggled on at runtime with the number keys.
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
    # `btm` — the other process monitor. It was a bare home.packages entry with
    # no config at all until now; moved here so its theming sits next to
    # btop's. bottom has no notion of following the terminal palette either,
    # and its stock look is the usual blue/green ratatui default.
    #
    # TextStyle-valued keys take a table ({ color, bg_color, bold, italics });
    # the plain *_color keys take a bare string. Mixing those up is a hard
    # parse error at startup, not a warning.
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
        # One entry per core, cycled. Deliberately a short rotation of the
        # cool half of the palette: with 22 threads on this machine a wide
        # rainbow is unreadable, and the warm half is reserved for the
        # avg/all lines so they stay findable in the pile.
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
    # Per-project shells. starship's format already carried a $direnv module
    # long before direnv was installed. nix-direnv caches the evaluated shell
    # and GC-roots it under .direnv/, so `use flake` is instant on re-entry
    # and survives `nh clean` without needing nix.settings.keep-outputs.
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # tldr client (the binary is still `tldr`). Replaces pkgs.tldr: cached
    # pages, no python startup. enableAutoUpdates refreshes the cache instead
    # of failing with "cache is stale" after a few weeks.
    tealdeer = {
      enable = true;
      enableAutoUpdates = true;
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
          enabled = true;
        };
        ai = {
          enabled = true;
        };
        # Ctrl-R opens filtered to the current git repo (cycle out with
        # Ctrl-R); with ~34k unique commands the repo cut is usually the
        # right first guess.
        workspaces = true;
        # No theme here on purpose: atuin's built-in colors were preferred to
        # an Ember-derived theme (tried and reverted 2026-08-18). It has full
        # theme support via programs.atuin.themes + settings.theme.name if
        # that is ever revisited.
      };
    };
    # Activate the PTY proxy (see atuinPtyProxyZsh above for what it buys).
    #
    # mkOrder 100 puts this ahead of every other initContent block, including
    # the mkBefore ones in iris.nix and zsh/default.nix. Ordering is about cost,
    # not correctness: the snippet `exec`s a proxy that respawns zsh, so that
    # second zsh re-reads .zshrc from the top. Everything sourced before the
    # exec is therefore paid for twice and thrown away — compinit, the plugin
    # sourcing, starship. First in the file means the wasted half is nothing.
    #
    # The re-exec is self-limiting: the snippet exports ATUIN_PTY_PROXY_ACTIVE
    # and skips when it is already set. Two consequences worth knowing:
    #
    #   - IRIS is unaffected. `i` execs a wrapper that spawns its own child
    #     zsh, and that child inherits the variable, so it does not stack a
    #     second proxy inside the first. The chain is proxy -> zsh -> iris ->
    #     zsh, with one shadow vt100 at the outside.
    #   - tmux is deliberately *not* exempt. The snippet also re-execs when
    #     $TMUX changes, so panes get their own proxy rather than inheriting
    #     the outer one — that is what keeps the popup's redraw aligned with
    #     the pane's scrollback rather than the outer terminal's.
    #
    # `source` rather than inlining the text with builtins.readFile: readFile
    # on a derivation is import-from-derivation, which drags a build into
    # every evaluation of this flake. Sourcing a store path costs one cached
    # file read per shell and keeps eval pure.
    #
    # The wrapper around the source is a tty guard. The snippet's own re-exec
    # test is `ACTIVE unset || $TMUX changed` — it is blind to a change of
    # *terminal*. A shell started on a new tty under the same $TMUX (nvim's
    # `:terminal`, script(1), any nested pty) therefore skips the exec but
    # still inherits ATUIN_PTY_PROXY_SOCKET, which now names a proxy owning a
    # *different* terminal. atuin's Ctrl-R attaches to that foreign proxy and
    # replays its shadow vt100 into this one: the outer tmux status bar, the
    # nvim tabline and a stack of old prompts painted in as text, and no
    # search UI at all. Verified 2026-08-20 by A/B on the socket alone.
    #
    # Dropping the stale socket rather than re-exec'ing a proxy for the new tty
    # is deliberate: a proxy per `:terminal` costs a process and a thrown-away
    # .zshrc pass on each one. Without the socket atuin just runs unproxied,
    # which is all it could ever do there anyway.
    #
    # Clearing ATUIN_PTY_PROXY_TTY *before* the source and re-exporting it
    # after is load-bearing, and is why the guard cannot simply sit after the
    # source: when the snippet does exec (a new tmux pane), the proxy's child
    # would otherwise inherit this shell's tty, see a mismatch, and throw away
    # its own brand-new and entirely legitimate socket. Only a shell that
    # reaches the last line without exec'ing owns the socket it is holding.
    zsh.initContent = lib.mkOrder 100 ''
      _atuin_pty_proxy_owner_tty=''${ATUIN_PTY_PROXY_TTY:-}
      unset ATUIN_PTY_PROXY_TTY
      if [[ -n ''${ATUIN_PTY_PROXY_SOCKET:-} && -n $_atuin_pty_proxy_owner_tty \
            && $_atuin_pty_proxy_owner_tty != ''${TTY:-$(tty)} ]]; then
        unset ATUIN_PTY_PROXY_SOCKET
      fi
      unset _atuin_pty_proxy_owner_tty
      source ${atuinPtyProxyZsh}
      export ATUIN_PTY_PROXY_TTY=''${TTY:-$(tty)}
    '';
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
      # Open the selection in an editor. This has to be set declaratively here
      # rather than appended from shell init: FZF_DEFAULT_OPTS is exported, so
      # an `export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind=..."` in zshrc
      # re-appends at every nesting level and the binding accumulates (a shell
      # three levels deep — terminal, tmux, subshell — carried three copies).
      # home-manager writes this into the session vars for zsh and nushell
      # alike, as a plain assignment, so it lands exactly once.
      #
      # Literal `nvim`, not `$EDITOR`: nushell loads these without shell
      # expansion. Both shells set EDITOR = "nvim" anyway.
      defaultOptions = [ "--bind='ctrl-e:execute(nvim {} > /dev/tty)+abort'" ];
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
