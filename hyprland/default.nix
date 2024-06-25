{pkgs, inputs, ...}:
let
  cursor-theme-name = "Bibata-Modern-Classic";
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    plugins = [
      pkgs.hy3 # make sure we are targetting the same version of hyprland and hy3
      # inputs.hycov.packages.x86_64-linux.hycov
      # inputs.hyprspace.packages.x86_64-linux.Hyprspace
    ];
    settings = {
      exec-once = [
        "${pkgs.dbus}/bin/dbus-update-activation-environment --all"
        "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "${pkgs.kdePackages.polkit-kde-agent-1}/bin/polkit-kde-agent-1"
      ];
    };
    systemd = {
      enable = true;
      variables = ["--all"];
      extraCommands = [
        "systemctl --user stop graphical-suession.target"
        "systemctl --user start hyprland-session.target"
        "systemctl start --user polkit-gnome-authentication-agent-1 "
      ];
    };
    xwayland.enable = true;
  };
  khome.desktop.pyprland = {
    enable = true;
  };
  home.file.".config/wal/templates/colors-hyprland.conf".source = ./colors-hyprland.conf;

  home.packages = with pkgs; [
    hyprlock

    grimblast

    imv
    mpv

    pw-volume

    libnotify

    wdisplays  # manage display positioning
    wl-clipboard  # wayland clipboard utilities

    polkit
    polkit_gnome  # Authenticator
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
    GTK_THEME = "WhiteSur-Dark-orange";  # For nautilus. Not working
    POLKIT_AUTH_AGENT = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  };

  gtk = {
    enable = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    # gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    theme = {
      package = pkgs.whitesur-gtk-theme.override {
        themeVariants = ["orange"];
      };
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

