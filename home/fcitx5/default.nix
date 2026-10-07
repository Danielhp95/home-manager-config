# fcitx5 via home-manager's i18n.inputMethod: ~/.config/fcitx5 is a read-only
# store symlink, so changes made in fcitx5-configtool must be ported here.
# fcitx5-daemon.service is WantedBy=graphical-session.target, so it survives
# hyprland's target restart. The pinyin user dict lives in ~/.local/share.
{ pkgs, theme, ... }:

let
  # The Ember skin goes in ~/.local/share (XDG_DATA_HOME) because two renderers
  # need it: the daemon's classicui, and the fcitx5-gtk/qt plugins that draw
  # the popup inside Firefox/Telegram and silently fall back to the white
  # default skin. The wrapper's share/ is daemon-only, and the per-user
  # profile doesn't link share/fcitx5.
  ember = pkgs.callPackage ./ember/package.nix { inherit theme; };
in
{
  xdg.dataFile."fcitx5/themes/Ember".source = "${ember}/share/fcitx5/themes/Ember";
  # The daemon reads the skin at start: restart it when the skin changes (a
  # palette switch), as noctalia and vicinae are for their themes.
  systemd.user.services.fcitx5-daemon.Unit.X-Restart-Triggers = [ "${ember}" ];

  # Masks the wrapper's XDG autostart entry: it raced fcitx5-daemon.service
  # for the D-Bus name.
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Hidden=true
  '';

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      # fcitx5-gtk, fcitx5-qt and fcitx5-configtool come with the wrapper.
      addons = [ pkgs.qt6Packages.fcitx5-chinese-addons ];

      # ~/.config/fcitx5: the options fcitx5-configtool would write.
      settings = import ./settings.nix { inherit theme; };
    };
  };
}
