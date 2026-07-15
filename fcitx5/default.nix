{ pkgs, ... }:

{
  # classicui (theme etc.) is enshrined below; still unmanaged from
  # ~/.config/fcitx5: `profile` (input method list) and `config` (hotkey state
  # beyond the trigger key).
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        rime-data
        fcitx5-gtk # Does help with making fcitx5 work in QT apps
        fcitx5-rime
        qt6Packages.fcitx5-configtool
        qt6Packages.fcitx5-chinese-addons
        fcitx5-rose-pine
        (import ./ember/package.nix { inherit (pkgs) stdenvNoCC lib; })
      ];
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys"."0" = "Alt+space"; # Trigger fcitx5
        };
        # Written to /etc/xdg/fcitx5/conf/classicui.conf. fcitx5 only falls
        # back to it when ~/.config/fcitx5/conf/classicui.conf does NOT exist
        # (the user file shadows it completely), so don't recreate that file
        # via fcitx5-configtool without porting changes back here.
        # This is the former user-level config verbatim, plus Theme=Ember.
        addons = {
          classicui.globalSection = {
            "Vertical Candidate List" = "False";
            WheelForPaging = "True";
            Font = "\"Sans 14\"";
            MenuFont = "\"Sans 14\"";
            TrayFont = "\"Sans Bold 14\"";
            TrayOutlineColor = "#000000";
            TrayTextColor = "#ffffff";
            PreferTextIcon = "False";
            ShowLayoutNameInIcon = "True";
            UseInputMethodLanguageToDisplayText = "True";
            Theme = "Ember";
            DarkTheme = "Ember";
            UseDarkTheme = "False";
            UseAccentColor = "True";
            PerScreenDPI = "False";
            ForceWaylandDPI = "0";
            EnableFractionalScale = "True";
          };
        };
      };
    };
  };
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
