{pkgs, ...}:
{
  programs.zellij = {
    enable = true;
    settings = {
      ui.pane_frames.rounded_corners = true;
      copy_on_select = false;
      scrollback_editor = "nvim --clean";
    };
  };
}
