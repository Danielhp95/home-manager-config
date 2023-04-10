# Git in vim plugin from tpope
{ pkgs, dsl, ... }:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
    vim-fugitive
    gitsigns-nvim
    diffview-nvim
  ];

  use.gitsigns.setup = callWith {};
  use.diffview.setup = callWith {};
}
