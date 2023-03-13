# Syntax highlighting for most languages using ASTs
{ pkgs, dsl, ... }:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
    pkgs.vimPlugins.nvim-treesitter.withAllGrammars
    playground # playground for treesitter
  ];
  lua = builtins.readFile ./treesitter.lua;
}
