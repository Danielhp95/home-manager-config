# Git in vim plugin from tpope
{ pkgs, dsl, ... }:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
    bufferline-nvim
  ];

  # TODO: add cool stuff
  use.bufferline.setup = callWith { };
}
