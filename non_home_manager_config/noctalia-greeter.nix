# Noctalia Greeter as the display manager (greetd). Settings reference:
# https://docs.noctalia.dev/greeter/configuration/
{ lib, pkgs, ... }:
let
  p = import ../palette.nix;

  # The greeter sets only XDG_SESSION_TYPE and the XDG_*_DESKTOP pair (from
  # DesktopNames=); the IM and wayland toolkit variables come from here.
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

  # start-hyprland is Hyprland's crash watchdog, called by name because
  # Hyprland comes from home-manager; output goes to the journal as
  # `hyprland`. home.sessionVariables are sourced last, so they win and reach
  # every systemd user service through Hyprland's env hook.
  startHyprland = pkgs.writeShellScript "start-hyprland-session" ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") sessionEnv)}
    hm_vars="/etc/profiles/per-user/''${USER:-$(${pkgs.coreutils}/bin/id -un)}/etc/profile.d/hm-session-vars.sh"
    if [ -r "$hm_vars" ]; then
      # shellcheck source=/dev/null
      . "$hm_vars"
    fi
    exec systemd-cat --identifier=hyprland start-hyprland "$@"
  '';

  # Found via /run/current-system/sw/share/wayland-sessions (pathsToLink
  # below). Name= is what [session].default matches.
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
  # The greeter reads avatars only via AccountsService, whose default (~/.face)
  # is behind a 0700 home, so Icon= points at the store copy. `f+` rewrites
  # the whole keyfile each boot, dropping anything else stored there.
  systemd.tmpfiles.rules = [
    "f+ /var/lib/AccountsService/users/dani 0600 root root - [User]\\nIcon=${../avatars/ratchet.png}\\nSystemAccount=false\\n"
  ];

  environment.systemPackages = [ hyprlandSession ];
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  services.displayManager.noctalia-greeter = {
    enable = true;

    # noctalia's greeter sync (shell.greeter_sync) pushes the wallpaper with no
    # password prompt; the complete palette below still wins over its colours.
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
