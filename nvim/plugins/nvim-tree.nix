# NERD tree style plugin, show a list of files + directories in a side panel
{ pkgs, ... }: {

  plugins = with pkgs.vimPlugins; [ nvim-tree-lua ];

  setup.nvim-tree = {
    disable_netrw = true;
    open_on_tab = false;
    hijack_cursor = false;
    sync_root_with_cwd = false;
    hijack_directories = {
      enable = true;
      auto_open = true;
    };
    diagnostics = {
      enable = false;
      icons = {
        hint = "";
        info = "";
        warning = "";
        error = "";
      };
    };
    update_focused_file = {
      enable = false;
      update_cwd = false;
      ignore_list = { };
    };
    system_open = {
      cmd = null;
      args = { };
    };
    filters = {
      dotfiles = false;
      custom = { };
    };
    git = {
      enable = true;
      ignore = true;
      timeout = 500;
    };
    actions.open_file.resize_window = false;
    view = {
      width = 30;
      hide_root_folder = false;
      side = "left";
      mappings = {
        custom_only = false;
        list = { };
      };
    };
  };
}
