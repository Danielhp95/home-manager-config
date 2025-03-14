{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  cursor-theme-name = "Bibata-Modern-Amber";
  # use OCR and copy to clipboard
  ocrScript =
    let
      inherit (pkgs)
        grim
        libnotify
        slurp
        tesseract5
        wl-clipboard
        ;
      _ = lib.getExe;
    in
    pkgs.writeShellScriptBin "wl-ocr" ''
      ${_ grim} -g "$(${_ slurp})" -t ppm - | ${_ tesseract5} - - | ${wl-clipboard}/bin/wl-copy
      ${_ libnotify} "$(${wl-clipboard}/bin/wl-paste)"
    '';
in
{
  programs.hyprlock = {
    enable = true;
    extraConfig = builtins.readFile ./hyprlock.conf;
  };
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    plugins = with pkgs; [
      hy3
      inputs.hyprtasking.packages.${pkgs.system}.hyprtasking
      # To lock after idling for too long
      # https://github.com/hyprwm/hypridle
    ];
    settings = {
      exec-once = [
        "${pkgs.dbus}/bin/dbus-update-activation-environment --all"
        "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME"
      ];
    };
    systemd = {
      enable = true;
      variables = [ "--all" ];
      extraCommands = [
        "systemctl --user start hyprpolkitagent"
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
        # TODO(1) Commenting scenario, not working
        # "systemctl start --user polkit-gnome-authentication-agent-1 "
      ];
    };
    xwayland.enable = true;
  };
  khome.desktop.pyprland = {
    enable = true;
  };
  home.file.".config/wal/templates/colors-hyprland.conf".source = ./colors-hyprland.conf;

  home.packages = with pkgs; [
    hyprpolkitagent # Authenticator

    # For screenshots
    hyprshot
    satty

    imv
    mpv

    pw-volume

    hyprpicker

    libnotify

    wdisplays # manage display positioning
    wl-clipboard # wayland clipboard utilities
    wl-mirror # For mirroring screens

    lxde.lxsession # Authenticator

    ocrScript
  ];

  # Cursor. This might not be necessary with hyprland 0.41
  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = cursor-theme-name;
    size = 20;
  };
  home.sessionVariables = {

    # TODO: this was introduced in November 2024, can we remove this at some point?
    # To surpress error: GSK-message Error 71 (Protocol error) dispatching to Wayland display.
    QT_QPA_PLATFORMTHEME = "gtk4";
    GTK_THEME = "WhiteSur-Dark-orange"; # For nautilus. Not working
    # TODO(1) Commenting scenario, not working
    # POLKIT_AUTH_AGENT =
    #   "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  };

  gtk = {
    enable = true;
    gtk4.extraConfig = {
      # TODO: This still places things under [Settings] and we want this to be placed under [AdwStyleManager]. How do we do it?
      AdwStyleManager = "color-scheme=ADW_COLOR_SCHEME_PREFER_DARK";
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    theme = {
      package = pkgs.whitesur-gtk-theme.override { themeVariants = [ "orange" ]; };
      name = "WhiteSur-Dark-orange";
    };

    iconTheme = {
      package = pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };

    font = {
      name = "Fira Code";
      size = 11;
    };
  };
  dconf.settings = {
    "org/gnome/desktop/interface".cursor-theme = cursor-theme-name;
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
