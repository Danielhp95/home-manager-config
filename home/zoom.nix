{ pkgs, host, ... }:
# Zoom runs under XWayland unless its own `xwayland=false` says otherwise, and
# hyprland.lua's force_zero_scaling leaves every X11 client to scale itself.
# Zoom's Qt would take the scale from Xft.dpi, which nothing sets here, so it
# drew at 1x on the panel. QT_SCREEN_SCALE_FACTORS gives the panel its scale by
# output name; a screen it does not name stays at 1x.
#
# `scaleFactor` in ~/.config/zoomus.conf scales every screen instead
# (ZoomLauncher exports it as QT_SCALE_FACTOR) and Qt multiplies the two: leave
# it unset.
let
  inherit (host) panel;

  zoom = pkgs.symlinkJoin {
    name = "zoom-hidpi";
    paths = [ pkgs.zoom-us ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "zoom";
    postBuild = ''
      wrapProgram $out/bin/zoom \
        --set QT_SCREEN_SCALE_FACTORS '${panel.output}=${toString panel.scale}'
      # Upstream's zoom-us links to the unwrapped zoom.
      ln -sf zoom $out/bin/zoom-us
    '';
  };
in
{
  home.packages = [ zoom ];
}
