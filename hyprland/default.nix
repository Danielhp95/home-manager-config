{
  pkgs,
  lib,
  inputs,
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
    # Hyprland >= 0.55 / nixpkgs 26.05 default: config is written in lua.
    # hy3 (hl0.55+) exposes its dispatchers under hl.plugin.hy3 in lua.
    configType = "lua";
    extraConfig = builtins.readFile ./hyprland.lua;
    plugins = with pkgs; [
      hy3
    ];
    # NOTE: the dbus-update-activation-environment exec-once entries that used to
    # live here are now in hyprland.lua's hl.on("hyprland.start", ...) hook, since
    # `settings` is serialized as hl.<name>(...) lua calls under configType = "lua".
    systemd = {
      enable = true;
      variables = [ "--all" ];
      extraCommands = [
        "systemctl --user start hyprpolkitagent"
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
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

    inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default # cooler screen picker

    # For screenshots
    hyprshot
    satty

    pw-volume

    hyprpicker

    libnotify

    wdisplays # manage display positioning
    wl-clipboard # wayland clipboard utilities
    wl-mirror # For mirroring screens

    lxsession # Authenticator

    ocrScript

    # This should really live on its own package
    slurp
    wf-recorder

    wl-kbptr # Mouse control with keyboard in wayland
    wlrctl # Command line utility for miscellaneous wlroots Wayland extensions
  ];

  # Battery notifications
  xdg.configFile."wl-kbptr.yaml".source = ./wl-kbptr.yaml;
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = hyprland-preview-share-picker
      allow_token_by_default = true
    }
  '';
  services.batsignal = {
    # TODO: This is not working
    enable = true;
    extraArgs = [
      "-d 5"
      "-c 10"
      "-w 30"
      "-f 97"
      "-D ${pkgs.systemd}/bin/systemctl suspend" # Suspend at danger level
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
