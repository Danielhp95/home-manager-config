# NERD tree style plugin, show a list of files + directories in a side panel
{ pkgs, dsl, ... }:
with dsl;
{

  plugins = with pkgs.vimPlugins; [
    fm-nvim
  ];

  use.fm-nvim.setup = callWith {
    float = {
      border = "double";
    };
    cmds = {
      broot = "${pkgs.broot}/bin/broot --out /tmp/fm-nvim";
      ranger = "${pkgs.ranger}/bin/ranger";
      xplr = "${pkgs.xplr}/bin/xplr";
    };
  };

}
