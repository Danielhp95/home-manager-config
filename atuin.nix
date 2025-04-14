{...}:
{
  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      enter_accept = true;  # Enter to execute, tab to select
      show_help = false;
      show_tabs = false;
      invert = true;
    };
  };
}
