# System fonts (NixOS-level). Lives under fcitx5/ because the CJK fonts exist
# for Chinese input; the input method itself is home-manager config in
# ./default.nix (imported from home.nix).
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      source-sans
      source-serif
      source-han-sans # chinese fonts
      source-han-serif # chinese fonts
    ];
    fontconfig.defaultFonts = {
      serif = [
        "Source Han Serif SC"
        "Source Han Serif TC"
        "Noto Color Emoji"
      ];
      sansSerif = [
        "Source Han Sans SC"
        "Source Han Sans TC"
        "Noto Color Emoji"
      ];
      monospace = [
        "FiraCode Nerd Font Mono"
        "Noto Color Emoji"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
