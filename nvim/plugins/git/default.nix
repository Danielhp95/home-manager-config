# Git in vim plugin from tpope
{ pkgs, dsl, ... }:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
    neogit
  ];

  use.neogit.setup = callWith {};
}
