# Telescope is a picker/searcher framework
# - fuzzy search like FZF with nicer UIs
# - integrations with Git, Vim Internal Info, LSP and more
# - can write custom pickers
{ pkgs, dsl, ... }:
with dsl; {
  plugins = with pkgs.vimPlugins; [
    # fuzzy finder
    plenary-nvim                   # Dependency for telescope
    telescope-nvim                 # One and only
    telescope-fzf-native-nvim
    # sexy dropdown
    telescope-ui-select-nvim       # It sets vim.ui.select to telescope
    telescope-live-grep-args-nvim  # Being able to pass arguments for ripgrep (used by live grep in Telescope)
  ];

  lua = ''
    function Cd(path)
        path = path or '.'
        cdPicker('Cd', {vim.o.shell, '-c', "${pkgs.fd}/bin/fd . "..path.." --type=d 2>/dev/null"})
    end
  '' + builtins.readFile ./telescope.lua;
}
