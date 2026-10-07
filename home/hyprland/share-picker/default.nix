# The screen-share picker xdg-desktop-portal-hyprland opens: window and monitor
# previews instead of a bare list. The package (./package.nix) is
# pkgs.hyprland-preview-share-picker through the overlay.
{ pkgs, theme, ... }:
{
  home.packages = [ pkgs.hyprland-preview-share-picker ];

  wayland.windowManager.hyprland.xdph.settings.screencopy = {
    custom_picker_binary = "hyprland-preview-share-picker";
    allow_token_by_default = true;
  };

  # Colours only, over the GTK theme's GTK4 widgets. `.window > box` is needed
  # because the picker's css_classes() drops GTK's `background` class.
  xdg.configFile."hyprland-preview-share-picker/config.yaml".text = ''
    stylesheets: [palette.css]
  '';
  # ./palette.css with each @slot@ filled in; the build fails on a name that is
  # not a slot.
  xdg.configFile."hyprland-preview-share-picker/palette.css".source = pkgs.replaceVars ./palette.css {
    inherit (theme.hash)
      accent
      accentBright
      bg
      bgAlt
      bgDeep
      border
      fg
      fgDim
      fgSoft
      muted
      surface
      ;
  };
}
