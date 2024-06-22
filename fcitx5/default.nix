{ pkgs, ... }:

{
  # TODO: enshrine in this config the info that you care about from ~/.config/fcitx5
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
        rime-data
        fcitx5-rime
        fcitx5-configtool
        fcitx5-chinese-addons
        fcitx5-rose-pine
      ];
  };
  fonts = {
    packages = with pkgs; [
      source-sans
      source-serif
      source-han-sans   # chinese fonts
      source-han-serif  # chinese fonts
      fira-code-nerdfont
      iosevka
    ];
    fontconfig.defaultFonts = {
      serif = ["Source Han Serif SC" "Source Han Serif TC" "Noto Color Emoji"];
      sansSerif = ["Source Han Sans SC" "Source Han Sans TC" "Noto Color Emoji"];
      monospace = ["FiraCode Nerd Font Mono" "Noto Color Emoji"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
