{ pkgs, config, ... }:
let
  p = (import ../palette.nix).hash;

  # Not on PATH: the sai venv's dart, as in noctalia/dart-plugin/plugin.toml.
  dart = "${config.home.homeDirectory}/Projects/sai/.venv/bin/dart";
in
{
  # pistol: the files channel's mime-dispatching previewer.
  home.packages = with pkgs; [
    pistol
    chafa # images -> ANSI art in the preview pane
  ];

  # First match wins; anything else falls through to pistol's built-ins.
  home.file.".config/pistol/pistol.conf".text = ''
    text/* sh: BAT_THEME=ansi bat -n --color=always --paging=never %pistol-filename%
    # --probe off: chafa's colour queries would land in tv's input box as
    # literal "rgb:..." text.
    image/* chafa -f symbols --animate off --probe off %pistol-filename%
  '';

  programs.television = {
    enable = true;

    # Each one is written to $XDG_CONFIG_HOME/television/cable/<name>.toml.
    channels = {
      dart = {
        metadata = {
          name = "dart";
          description = "A channel to select dart runs";
          requirements = [ dart ];
        };
        source.command = [ "${dart} run filter | sed -e '1d' -e '$d' | sed -e 's/\"//g' -e 's/,$//'" ];
        preview.command = "${dart} run get --tags {}";
      };

      # The cable-repo files channel, but its default source lists all files
      # (hidden and gitignored, minus .git); <C-s> cycles to the filtered one.
      files = {
        metadata = {
          name = "files";
          description = "A channel to select files and directories";
          requirements = [
            "fd"
            "pistol"
          ];
        };
        source.command = [
          {
            name = "All";
            run = "fd -t f -H -I -E .git";
          }
          {
            name = "Filtered";
            run = "fd -t f";
          }
        ];
        # pistol dispatches by mime type (pistol.conf above).
        preview.command = "pistol '{}'";
        keybindings = {
          shortcut = "f1";
          f12 = "actions:edit";
          "ctrl-up" = "actions:goto_parent_dir";
        };
        actions = {
          edit = {
            description = "Opens the selected entries with the default editor (falls back to vim)";
            command = "\${EDITOR:-vim} {}";
            shell = "bash";
            # use `mode = "fork"` if you want to return to tv afterwards
            mode = "execute";
          };
          goto_parent_dir = {
            description = "Re-opens tv in the parent directory";
            command = "tv files ..";
            mode = "execute";
          };
        };
      };

      # The cable-repo text channel; its Enter action is what makes yazi's <C-g>
      # open $EDITOR at the matched line.
      text = {
        metadata = {
          name = "text";
          description = "A channel to find and select text from files";
          requirements = [
            "rg"
            "bat"
          ];
        };
        source = {
          command = [
            {
              name = "Default";
              run = "rg . --no-heading --line-number --colors 'match:fg:white' --colors 'path:fg:blue' --color=always";
            }
            {
              name = "Hidden";
              run = "rg . --no-heading --line-number --hidden --colors 'match:fg:white' --colors 'path:fg:blue' --color=always";
            }
          ];
          ansi = true;
          output = "{strip_ansi|split:\\::..2}";
        };
        preview = {
          command = "bat -n --color=always '{strip_ansi|split:\\::0}'";
          env.BAT_THEME = "ansi";
          offset = "{strip_ansi|split:\\::1}";
        };
        ui.preview_panel.header = "{strip_ansi|split:\\::..2}";
        keybindings.enter = "actions:edit";
        actions.edit = {
          description = "Open file in editor at line";
          command = "\${EDITOR:-vim} '+{strip_ansi|split:\\::1}' '{strip_ansi|split:\\::0}'";
          shell = "bash";
          mode = "execute";
        };
      };

      # Frecency-ranked dirs; the cd/z/zz triggers below pick this over the
      # fd-based dirs channel.
      zoxide = {
        metadata = {
          name = "zoxide";
          description = "A channel to select directories ranked by zoxide frecency";
          requirements = [
            "zoxide"
            "eza"
          ];
        };
        source.command = "zoxide query --list";
        # tv passes no width and stdout is a pipe, so read it from the tty.
        # --icons needs =always, or it swallows the next argument.
        preview.command = "w=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2); w=$((\${w:-100} - 6)); eza --grid --across --icons=always --color=always -w $w '{}'; echo; git -C '{}' log --oneline -5 2>/dev/null || true";
        # Stacked layout: preview below the results, full path as its header
        ui = {
          orientation = "portrait";
          preview_panel = {
            size = 60;
            header = "{}";
          };
        };
        keybindings.shortcut = "f2";
      };

      # Generation switcher behind the `ng` alias. Lists the profile links
      # directly (nix-env -p on the system profile needs root) and hands the
      # chosen link to `nh os switch` as a path installable.
      nix-generations = {
        metadata = {
          name = "nix-generations";
          description = "A channel to inspect and switch NixOS system generations";
          requirements = [
            "nvd"
            "nh"
          ];
        };
        # stat the link itself: its target's mtime is nix-normalized to 1970
        source.command = "for link in /nix/var/nix/profiles/system-*-link; do num=\"\${link##*system-}\"; num=\"\${num%-link}\"; printf '%s %s\\n' \"$num\" \"$(stat -c '%.16y' \"$link\")\"; done | sort -rn";
        preview.command = "nvd diff '/nix/var/nix/profiles/system-{split: :0}-link' /nix/var/nix/profiles/system";
        keybindings.enter = "actions:switch";
        actions.switch = {
          description = "Switch the system to the selected generation";
          command = "nh os switch '/nix/var/nix/profiles/system-{split: :0}-link'";
          shell = "bash";
          mode = "execute";
        };
      };

      # NixOS/home-manager option search via manix; the sed trims its
      # "# option.path (source)" lines to the bare path.
      nix-options = {
        metadata = {
          name = "nix-options";
          description = "A channel to search NixOS/home-manager options and nixpkgs docs";
          requirements = [ "manix" ];
        };
        source.command = "manix \"\" | grep '^# ' | sed 's/^# \\(.*\\) (.*/\\1/;s/ (.*//'";
        preview.command = "manix '{}'";
      };
    };

    # Written to $XDG_CONFIG_HOME/television/config.toml.
    settings = {
      tick_rate = 50;
      default_channel = "files";
      history_size = 200;
      global_history = false;

      ui = {
        ui_scale = 100;
        orientation = "landscape";
        theme = "default";
        input_bar = {
          position = "top";
          prompt = ">";
          border_type = "rounded";
        };
        status_bar = {
          separator_open = "";
          separator_close = "";
          hidden = false;
        };
        results_panel.border_type = "rounded";
        preview_panel = {
          size = 50;
          scrollbar = true;
          border_type = "rounded";
          hidden = false;
        };
        help_panel = {
          show_categories = true;
          hidden = true;
        };
        remote_control = {
          show_channel_descriptions = true;
          sort_alphabetically = true;
        };

        # Ember over tv's `default` theme. These are all the keys tv 0.15.9's
        # ThemeOverrides accepts; unknown names are silently ignored.
        theme_overrides = {
          background = p.bg;
          border_fg = p.border;
          text_fg = p.fg;
          dimmed_text_fg = p.fgDim;
          input_text_fg = p.fg;
          result_count_fg = p.steel;
          result_name_fg = p.fg;
          result_line_number_fg = p.steel;
          result_value_fg = p.fgDim;
          selection_bg = p.surface;
          selection_fg = p.fg;
          match_fg = p.accentBright;
          preview_title_fg = p.steel;
          channel_mode_fg = p.bg;
          channel_mode_bg = p.accent;
          remote_control_mode_fg = p.bg;
          remote_control_mode_bg = p.sage;
          action_picker_mode_fg = p.bg;
          action_picker_mode_bg = p.mauve;
        };
      };

      keybindings = {
        esc = "quit";
        "ctrl-c" = "quit";
        down = "select_next_entry";
        "ctrl-n" = "select_next_entry";
        "ctrl-j" = "select_next_entry";
        up = "select_prev_entry";
        "ctrl-p" = "select_prev_entry";
        "ctrl-k" = "select_prev_entry";
        "ctrl-up" = "select_prev_history";
        "ctrl-down" = "select_next_history";
        tab = "select_next_entry";
        backtab = "select_prev_entry";
        # Multi-select lives here: tab navigates instead of tv's default.
        "ctrl-space" = "toggle_selection_down";
        enter = "confirm_selection";
        pagedown = "scroll_preview_half_page_down";
        pageup = "scroll_preview_half_page_up";
        "ctrl-y" = "copy_entry_to_clipboard";
        "ctrl-r" = "reload_source";
        "ctrl-s" = "cycle_sources";
        "ctrl-t" = "toggle_remote_control";
        "ctrl-o" = "toggle_preview";
        "ctrl-h" = "toggle_help";
        f12 = "toggle_status_bar";
        "ctrl-l" = "toggle_layout";
        backspace = "delete_prev_char";
        "ctrl-w" = "delete_prev_word";
        "ctrl-u" = "delete_line";
        delete = "delete_next_char";
        left = "go_to_prev_char";
        right = "go_to_next_char";
        home = "go_to_input_start";
        "ctrl-a" = "go_to_input_start";
        end = "go_to_input_end";
        "ctrl-e" = "go_to_input_end";
      };

      shell_integration = {
        fallback_channel = "files";
        channel_triggers = {
          env = [
            "export"
            "unset"
          ];
          dirs = [
            "ls"
            "rmdir"
          ];
          zoxide = [
            "cd"
            "z"
            "zz"
          ];
          files = [
            "cat"
            "less"
            "head"
            "tail"
            "vim"
            "nano"
            "bat"
            "cp"
            "mv"
            "rm"
            "touch"
            "chmod"
            "chown"
            "ln"
            "tar"
            "zip"
            "unzip"
            "gzip"
            "gunzip"
            "xz"
          ];
          "git-diff" = [
            "git add"
            "git restore"
          ];
          "git-branch" = [
            "git checkout"
            "git branch"
            "git merge"
            "git rebase"
            "git pull"
            "git push"
          ];
          "git-log" = [
            "git log"
            "git show"
          ];
          "git-repos" = [ "git clone" ];
        };
        keybindings = {
          smart_autocomplete = "ctrl-t";
          command_history = "ctrl-r";
        };
      };
    };
  };
}
