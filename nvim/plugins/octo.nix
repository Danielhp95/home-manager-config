{ pkgs, dsl, ... }:
with dsl; {
  plugins = with pkgs.vimPlugins; [
    pkgs.gh  # Github cli
    octo-nvim  # Github cli in linux
  ];
  use.octo.setup = callWith {};
}
