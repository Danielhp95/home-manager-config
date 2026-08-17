{ pkgs, inputs, ... }:
let
  p = (import ../palette.nix).hash;
in
{
  # Mime-dispatching previewer backing the files channel's preview (and usable
  # anywhere else a single preview command is wanted: fzf, lf, ...).
  home.packages = with pkgs; [
    pistol
    chafa # images -> ANSI art in the preview pane
  ];

  # First matching line wins. Anything not matched here falls through to
  # pistol's built-ins: chroma-highlighted text, archive/dir listings,
  # libmagic descriptions for binaries.
  home.file.".config/pistol/pistol.conf".text = ''
    text/* sh: BAT_THEME=ansi bat -n --color=always --paging=never %pistol-filename%
    # --probe off: chafa's default terminal probe writes OSC 10/11 color queries
    # to the tty; when tv owns the tty the replies land in its input box as
    # literal "rgb:..." text. Symbols mode gains nothing from probing anyway.
    image/* chafa -f symbols --animate off --probe off %pistol-filename%
  '';

  home.file.".config/television/cable/dart.toml".text = ''
    [metadata]
    name = "dart"
    description = "A channel to select dart runs"
    requirements = ["dart"]

    [source]
    command = ["dart run filter | sed -e '1d' -e '$d' | sed -e 's/\"//g' -e 's/,$//'"]

    [preview]
    command = "dart run get --tags {}"
  '';

  # Pin the files channel (from television 0.15.9's cable repo) so the
  # default source lists ALL files (hidden + gitignored, minus .git) instead
  # of fd's default gitignore-respecting listing. <C-s> cycles to a
  # gitignore-filtered source. `tv update-channels` won't touch this.
  home.file.".config/television/cable/files.toml".text = ''
    [metadata]
    name = "files"
    description = "A channel to select files and directories"
    requirements = ["fd", "pistol"]

    [source]
    command = [
      { name = "All",      run = "fd -t f -H -I -E .git" },
      { name = "Filtered", run = "fd -t f" },
    ]

    [preview]
    # pistol dispatches by mime type (config below): bat for text, chafa for
    # images, built-in listings for archives/dirs, libmagic for the rest
    command = "pistol '{}'"

    [keybindings]
    shortcut = "f1"
    f12 = "actions:edit"
    ctrl-up = "actions:goto_parent_dir"

    [actions.edit]
    description = "Opens the selected entries with the default editor (falls back to vim)"
    command = "''${EDITOR:-vim} {}"
    shell = "bash"
    # use `mode = "fork"` if you want to return to tv afterwards
    mode = "execute"

    [actions.goto_parent_dir]
    description = "Re-opens tv in the parent directory"
    command = "tv files .."
    mode = "execute"
  '';

  # Pin the text channel (from television 0.15.9's cable repo): its
  # [actions.edit] on enter is what makes yazi's <C-g> open $EDITOR at the
  # matched line. `tv update-channels` won't touch this managed file.
  home.file.".config/television/cable/text.toml".text = ''
    [metadata]
    name = "text"
    description = "A channel to find and select text from files"
    requirements = ["rg", "bat"]

    [source]
    command = [
      { name = "Default", run = "rg . --no-heading --line-number --colors 'match:fg:white' --colors 'path:fg:blue' --color=always" },
      { name = "Hidden",  run = "rg . --no-heading --line-number --hidden --colors 'match:fg:white' --colors 'path:fg:blue' --color=always" },
    ]
    ansi = true
    output = "{strip_ansi|split:\\::..2}"

    [preview]
    command = "bat -n --color=always '{strip_ansi|split:\\::0}'"
    env = { BAT_THEME = "ansi" }
    offset = '{strip_ansi|split:\::1}'

    [ui]
    preview_panel = { header = '{strip_ansi|split:\::..2}' }

    [keybindings]
    enter = "actions:edit"

    [actions.edit]
    description = "Open file in editor at line"
    command = "''${EDITOR:-vim} '+{strip_ansi|split:\\::1}' '{strip_ansi|split:\\::0}'"
    shell = "bash"
    mode = "execute"
  '';

  # Frecency-ranked directory jumps. Wired into shell_integration's
  # channel_triggers below so `z `/`cd ` + smart-autocomplete (ctrl-t / zsh
  # Tab-Tab) pops this instead of the fd-based dirs channel.
  home.file.".config/television/cable/zoxide.toml".text = ''
    [metadata]
    name = "zoxide"
    description = "A channel to select directories ranked by zoxide frecency"
    requirements = ["zoxide", "eza"]

    [source]
    command = "zoxide query --list"

    [preview]
    # Multi-column grid + recent commits when the dir is (in) a repo. tv gives
    # the preview command no size info and stdout is a pipe (eza would assume
    # 80 cols), but the command inherits the terminal's tty — stty reads the
    # real width, which the portrait preview pane spans fully. --icons takes
    # an optional [<WHEN>] value, so it must be =always or it swallows the
    # next argument.
    command = "w=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2); w=$((''${w:-100} - 6)); eza --grid --across --icons=always --color=always -w $w '{}'; echo; git -C '{}' log --oneline -5 2>/dev/null || true"

    # Stacked layout: preview below the results, full path as its header
    [ui]
    orientation = "portrait"
    preview_panel = { size = 60, header = "{}" }

    [keybindings]
    shortcut = "f2"
  '';

  # System generation switcher backing the `ng` alias in zsh and nushell.
  # Reads the generation links from /nix/var/nix/profiles directly: `nix-env
  # --list-generations` without -p lists the *user* profile, and with -p the
  # system profile it needs root (system.lock). Enter hands the selected
  # generation link to `nh os switch` as a path installable
  # (`-- --switch-generation N` would hand the flag to nix build).
  home.file.".config/television/cable/nix-generations.toml".text = ''
    [metadata]
    name = "nix-generations"
    description = "A channel to inspect and switch NixOS system generations"
    requirements = ["nvd", "nh"]

    [source]
    # stat the link itself: its target's mtime is nix-normalized to 1970
    command = "for link in /nix/var/nix/profiles/system-*-link; do num=\"''${link##*system-}\"; num=\"''${num%-link}\"; printf '%s %s\\n' \"$num\" \"$(stat -c '%.16y' \"$link\")\"; done | sort -rn"

    [preview]
    command = "nvd diff '/nix/var/nix/profiles/system-{split: :0}-link' /nix/var/nix/profiles/system"

    [keybindings]
    enter = "actions:switch"

    [actions.switch]
    description = "Switch the system to the selected generation"
    command = "nh os switch '/nix/var/nix/profiles/system-{split: :0}-link'"
    shell = "bash"
    mode = "execute"
  '';

  # NixOS / home-manager option search via manix (installed in home.nix).
  # manix lists matches as "# option.path (source)"; the sed strips that down
  # to the bare option path (manix's own README fzf recipe, tv-ified).
  home.file.".config/television/cable/nix-options.toml".text = ''
    [metadata]
    name = "nix-options"
    description = "A channel to search NixOS/home-manager options and nixpkgs docs"
    requirements = ["manix"]

    [source]
    command = "manix \"\" | grep '^# ' | sed 's/^# \\(.*\\) (.*/\\1/;s/ (.*//'"

    [preview]
    command = "manix '{}'"
  '';

  # Ember theme configuration for television
  home.file.".config/television/config.toml".text = ''
    # Ember Theme Configuration for Television
    # ═══════════════════════════════════════════════════════════════════════════

    tick_rate = 50
    default_channel = "files"
    history_size = 200
    global_history = false

    [ui]
    ui_scale = 100
    orientation = "landscape"
    theme = "default"

    [ui.input_bar]
    position = "top"
    prompt = ">"
    border_type = "rounded"

    [ui.status_bar]
    separator_open = ""
    separator_close = ""
    hidden = false

    [ui.results_panel]
    border_type = "rounded"

    [ui.preview_panel]
    size = 50
    scrollbar = true
    border_type = "rounded"
    hidden = false

    [ui.help_panel]
    show_categories = true
    hidden = true

    [ui.remote_control]
    show_channel_descriptions = true
    sort_alphabetically = true

    # Ember colors from palette.nix (this block used to carry drifted local
    # copies; coral = accent, the theme's orange stand-in)
    # ═══════════════════════════════════════════════════════════════════════════
    [ui.theme_overrides]
    # Base colors
    background = "${p.bg}"
    text_fg = "${p.fg}"
    text_muted_fg = "${p.fgDim}"

    # Selection and highlights
    selection_bg = "${p.surface}"
    selection_fg = "${p.fg}"
    match_fg = "${p.accentBright}"
    match_bg = "${p.bg}"

    # UI elements
    border_fg = "${p.border}"
    border_active_fg = "${p.accent}"
    scrollbar_fg = "${p.border}"

    # Input and prompt
    input_fg = "${p.fg}"
    input_bg = "${p.bg}"
    prompt_fg = "${p.accent}"

    # Preview panel
    preview_fg = "${p.fg}"
    preview_bg = "${p.bg}"
    preview_border_fg = "${p.border}"
    preview_title_fg = "${p.steel}"

    # Status and info — info is neutral (steel); gold is reserved for
    # warnings so the two actually read differently
    status_fg = "${p.fgDim}"
    status_bg = "${p.bgAlt}"
    info_fg = "${p.steel}"
    success_fg = "${p.olive}"
    warning_fg = "${p.gold}"
    error_fg = "${p.error}"

    # Help panel
    help_fg = "${p.fg}"
    help_bg = "${p.bg}"
    help_title_fg = "${p.accent}"
    help_key_fg = "${p.accent}"

    # Channel selector (remote control)
    channel_fg = "${p.fg}"
    channel_selected_fg = "${p.accent}"
    channel_desc_fg = "${p.fgDim}"

    # Keybindings
    [keybindings]
    esc = "quit"
    ctrl-c = "quit"
    down = "select_next_entry"
    ctrl-n = "select_next_entry"
    ctrl-j = "select_next_entry"
    up = "select_prev_entry"
    ctrl-p = "select_prev_entry"
    ctrl-k = "select_prev_entry"
    ctrl-up = "select_prev_history"
    ctrl-down = "select_next_history"
    tab = "select_next_entry"
    backtab = "select_prev_entry"
    # tab is remapped to navigation above (tv's default is toggle_selection),
    # so multi-select lives here instead
    ctrl-space = "toggle_selection"
    enter = "confirm_selection"
    pagedown = "scroll_preview_half_page_down"
    pageup = "scroll_preview_half_page_up"
    ctrl-y = "copy_entry_to_clipboard"
    ctrl-r = "reload_source"
    ctrl-s = "cycle_sources"
    ctrl-t = "toggle_remote_control"
    ctrl-o = "toggle_preview"
    ctrl-h = "toggle_help"
    f12 = "toggle_status_bar"
    ctrl-l = "toggle_layout"
    backspace = "delete_prev_char"
    ctrl-w = "delete_prev_word"
    ctrl-u = "delete_line"
    delete = "delete_next_char"
    left = "go_to_prev_char"
    right = "go_to_next_char"
    home = "go_to_input_start"
    ctrl-a = "go_to_input_start"
    end = "go_to_input_end"
    ctrl-e = "go_to_input_end"

    [events]
    mouse-scroll-up = "scroll_preview_up"
    mouse-scroll-down = "scroll_preview_down"

    [shell_integration]
    fallback_channel = "files"

    [shell_integration.channel_triggers]
    "alias" = ["alias", "unalias"]
    "env" = ["export", "unset"]
    "dirs" = ["ls", "rmdir"]
    "zoxide" = ["cd", "z", "zz"]
    "files" = ["cat", "less", "head", "tail", "vim", "nano", "bat", "cp", "mv", "rm", "touch", "chmod", "chown", "ln", "tar", "zip", "unzip", "gzip", "gunzip", "xz"]
    "git-diff" = ["git add", "git restore"]
    "git-branch" = ["git checkout", "git branch", "git merge", "git rebase", "git pull", "git push"]
    "git-log" = ["git log", "git show"]
    "docker-images" = ["docker run"]
    "git-repos" = [ "code", "hx", "git clone"]

    [shell_integration.keybindings]
    "smart_autocomplete" = "ctrl-t"
    "command_history" = "ctrl-r"
  '';

  programs = {
    television = {
      enable = true;
      # enableZshIntegration = true;
    };
  };
}
