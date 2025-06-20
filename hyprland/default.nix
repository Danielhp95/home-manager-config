{
  pkgs,
  lib,
  ...
}:
let
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
  imports = [ ./theming.nix ];
  programs.hyprlock = {
    enable = true;
    extraConfig = builtins.readFile ./hyprlock.conf;
  };
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    plugins = with pkgs; [
      hy3
      hyprtasking
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

    # This should really live on its own package
    slurp
    wf-recorder
  ];

  # Battery notifications
  services.batsignal = {
    # TODO: This is not working
    enable = true;
    extraArgs = [
      "-d 5"
      "-c 10"
      "-w 30"
      "-f 97"
      "-D ${pkgs.systemd}/bin/systemctl suspend"  # Suspend at danger level
      # "-C" "Running out of Stormlight"
      # "-W" "Draining Stormlight at an alarming rate"
      # "-F" "Stormlight reserves full"
      # "-e" # Cause notifications to expire
      # "-p -P Charging Stormlight"
      # "-U Discharging Stormlight"
      # "-i" # Ignore missing battery notifications, for desktops
      # "-I 🔋" # Icon
    ];
  };
}
