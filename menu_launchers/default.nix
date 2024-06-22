{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "Fira Code 30";
    extraConfig = {
      width = 100;
      lines = 10;
      columns = 1;
      icon-theme = "Papirus-Dark";
      bw = 7;
      location = 0;
      padding = 5;
      yoffset = 0;
      xoffset = 0;
      fixed-num-lines = true;
      show-icons = true;
      ssh-client = "ssh";
      ssh-command = "{terminal} -e {ssh-client} {host}";
      run-command = "{cmd}";
      parse-hosts = true;
      matching = "fuzzy";
      separator-style = "none";
      scrollbar-width = 0;
      kb-mode-next = "Shift+Right,Control+Tab";
      kb-mode-previous = "Shift+Left,Control+Shift+Tab,Alt+h";
      kb-row-up = "Up,Control+p,Shift+Tab,Shift+ISO_Left_Tab,Alt+k";
      kb-row-down = "Down,Control+n,Alt+j";
    };
    theme = ./rofi/spotlight_dark.rasi;  # Personal theme
    # theme = "~/.cache/wal/colors-rofi-dark.rasi";
    terminal = "wezterm";
    plugins = with pkgs; [
      rofi-file-browser
      pywal
    ];
  };
  home.packages = with pkgs; [
    papirus-icon-theme
  ];
}
