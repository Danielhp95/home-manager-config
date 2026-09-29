# Noctalia Greeter as the display manager: greetd launches
# noctalia-greeter-session, which runs the greeter inside its own bundled
# wlroots compositor. The nixpkgs module enables greetd, AccountsService (the
# greeter's user list and avatars) and Polkit, and writes `settings` to
# /var/lib/noctalia-greeter/greeter.toml. Configuration reference:
# https://docs.noctalia.dev/greeter/configuration/
{ lib, pkgs, ... }:
let
  p = import ../palette.nix;

  # Same environment the old tuigreet hyprland session exported. The greeter
  # itself only sets XDG_SESSION_TYPE and derives XDG_CURRENT_DESKTOP /
  # XDG_SESSION_DESKTOP from the entry's DesktopNames=; everything else (the
  # fcitx IM modules, the wayland toolkit switches) still has to come from
  # here.
  sessionEnv = {
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    NIXOS_OZONE_WL = "1";
    GLFW_IM_MODULE = "fcitx";
    GTK_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    XMODIFIERS = "@im=fcitx";
    IMSETTINGS_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GSK_RENDERER = "gl";
  };

  # start-hyprland is Hyprland's own watchdog binary: it execs Hyprland and
  # restarts it if it dies non-cleanly. It is called by name because Hyprland
  # comes from home-manager (hyprland/default.nix), not the system profile.
  # stdout/stderr go to the journal under the `hyprland` identifier.
  startHyprland = pkgs.writeShellScript "start-hyprland-session" ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") sessionEnv)}
    exec systemd-cat --identifier=hyprland start-hyprland "$@"
  '';

  # The greeter discovers sessions from wayland-sessions directories, among
  # them /run/current-system/sw/share (hence the pathsToLink below). Name= is
  # both the picker label and what [session].default matches.
  hyprlandSession = pkgs.writeTextFile {
    name = "hyprland-session";
    destination = "/share/wayland-sessions/hyprland.desktop";
    text = ''
      [Desktop Entry]
      Name=Hyprland
      Comment=Hyprland via start-hyprland
      Exec=${startHyprland}
      Type=Application
      DesktopNames=Hyprland
    '';
  };
in
{
  environment.systemPackages = [ hyprlandSession ];
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  services.displayManager.noctalia-greeter = {
    enable = true;

    # noctalia's Settings -> Security -> Sync Now / auto-sync
    # (shell.greeter_sync in noctalia/default.nix) pushes the current
    # wallpaper to the greeter without a password prompt. The palette below
    # is complete, so it wins over whatever colours Sync sends.
    passwordlessSyncUsers = [ "dani" ];

    # Same cursor as the session (hyprland/theming.nix).
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Amber";
    };

    settings = {
      session.default = "Hyprland";
      # Opens straight on dani's password step; Esc goes back to the user list.
      user.default = "dani";

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
        font_family = (import ../fonts.nix).ui;
        # Ember, slot for slot as noctalia/default.nix maps it for the shell.
        palette = {
          primary = p.hash.accent;
          on_primary = p.hash.bg;
          secondary = p.hash.gold;
          on_secondary = p.hash.bg;
          tertiary = p.hash.sage;
          on_tertiary = p.hash.bg;
          error = p.hash.error;
          on_error = p.hash.bg;
          surface = p.hash.bg;
          on_surface = p.hash.fg;
          surface_variant = p.hash.surface;
          on_surface_variant = p.hash.fgSoft;
          outline = p.hash.border;
          shadow = p.hash.bgDeep;
          hover = p.hash.accentBright;
          on_hover = p.hash.bg;
        };
      };

      cursor.size = 20;

      # Mirrors input.kb_layout / kb_options in hyprland/hyprland.lua.
      keyboard = {
        layout = "us";
        options = "caps:escape";
      };
    };
  };
}
