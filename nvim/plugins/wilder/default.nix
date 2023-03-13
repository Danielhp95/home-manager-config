# Fancy vim menus for ':', ':', '/', '?'
# allows fuzzy searching terms better
{ pkgs, ... }:
{
  plugins = with pkgs; [
    vimPlugins.wilder-nvim
    vimPlugins.cpsm
    fd
  ];
  lua = ''
    local fd_path = '${pkgs.fd}/bin/fd'
  '' + builtins.readFile ./wilder.lua;
}
