{ pkgs, inputs, ... }:
{
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

    # Ember Theme Color Overrides
    # ═══════════════════════════════════════════════════════════════════════════
    [ui.theme_overrides]
    # Base colors
    background = "#1c1b19"           # bg0 - base background
    text_fg = "#d8d0c0"              # fg0 - primary text
    text_muted_fg = "#b8b0a0"        # fg1 - secondary text

    # Selection and highlights
    selection_bg = "#2c2b29"         # bg1 - surface layer 1
    selection_fg = "#d8d0c0"         # fg0 - primary text
    match_fg = "#e08060"             # coral - matched text highlight
    match_bg = "#1c1b19"             # bg0 - match background

    # UI elements
    border_fg = "#3c3b39"            # bg2 - borders
    border_active_fg = "#c09058"     # orange - active border (changed from steel)
    scrollbar_fg = "#4c4b49"         # bg3 - scrollbar

    # Input and prompt
    input_fg = "#d8d0c0"             # fg0 - input text
    input_bg = "#1c1b19"             # bg0 - input background
    prompt_fg = "#c09058"            # orange - prompt (changed from steel)

    # Preview panel
    preview_fg = "#d8d0c0"           # fg0 - preview text
    preview_bg = "#1c1b19"           # bg0 - preview background
    preview_border_fg = "#3c3b39"    # bg2 - preview border
    preview_title_fg = "#c8b468"     # gold - preview title

    # Status and info
    status_fg = "#b8b0a0"            # fg1 - status text
    status_bg = "#2c2b29"            # bg1 - status background
    info_fg = "#c8b468"              # gold - info messages
    success_fg = "#8a9868"           # olive - success messages
    warning_fg = "#c09058"           # orange - warnings
    error_fg = "#e08060"             # coral - errors

    # Help panel
    help_fg = "#d8d0c0"              # fg0 - help text
    help_bg = "#1c1b19"              # bg0 - help background
    help_title_fg = "#c09058"        # orange - help titles (changed from steel)
    help_key_fg = "#e08060"          # coral - key bindings

    # Channel selector (remote control)
    channel_fg = "#d8d0c0"           # fg0 - channel names
    channel_selected_fg = "#e08060"  # coral - selected channel
    channel_desc_fg = "#989088"      # fg2 - channel descriptions

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
    "dirs" = ["cd", "ls", "rmdir", "z"]
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
