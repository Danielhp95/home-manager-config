{pkgs, ...}:
{
  programs.zellij = {
    enable = true;
    package = pkgs.zellij.overrideAttrs ( oldAttrs: { version = "0.36"; } );
    settings = {
      ui.pane_frames.rounded_corners = true;
      copy_on_select = false;
      scrollback_editor = "nvim --clean";
    };
  };
}
