{pkgs, lib, home, inputs, stableWithUnfree, ...}:
{
  home.packages = with pkgs; [
    i3bar-river
    i3status-rust
  ];

  home.file.".config/i3bar-river/config.toml" = ''
    # The status generator command.
    # Optional: with no status generator the bar will display only tags and layout name.
     command = "i3status-rs"

    # Colors
    background = "#282828ff"
    color = "#ffffffff"
    separator = "#9a8a62ff"
    tag_fg = "#d79921ff"
    tag_bg = "#282828ff"
    tag_focused_fg = "#1d2021ff"
    tag_focused_bg = "#689d68ff"
    tag_urgent_fg = "#282828ff"
    tag_urgent_bg = "#cc241dff"
    tag_inactive_fg = "#d79921ff"
    tag_inactive_bg = "#282828ff"

    # The font and various sizes
    font = "JetBrainsMono Nerd Font 10"
    height = 20
    margin_top = 0
    margin_bottom = 0
    margin_left = 0
    margin_right = 0
    separator_width = 2.0
    tags_r = 0.0
    tags_padding = 10.0
    blocks_r = 0.0
    blocks_overlap = 0.0

    # Misc
    position = "top" # either "top" or "bottom"
    hide_inactive_tags = true
    invert_touchpad_scrolling = true
    show_layout_name = true
    blend = true # whether tags/blocks colors should blend with bar's background
    show_mode = true
  '';
}
