{ config, lib, pkgs, ... }:
let
  cfg = config.khome.tuigreet;
  inherit (lib)
    attrValues
    concatStringsSep
    filter
    filterAttrs
    mapAttrs
    mapAttrsToList
    mdDoc
    mkDefault
    mkIf
    mkOption
    recursiveUpdate
    types
    ;

  mkScript = session: scfg: pkgs.writeScript "greetd-start-${session}" ''
    ${concatStringsSep "\n" (mapAttrsToList (env: val: "export ${env}=${val}") scfg.environment)}
    exec systemd-cat --identifier=${session} ${scfg.command} $@
  '';

  sessionModule = { name, config, ... }: {
    options = {
      enable = mkOption {
        default = true;
        description = mdDoc "`enable` this session.";
        type = types.bool;
      };
      session = mkOption {
        default = name;
        description = mdDoc "session name";
        type = types.str;
      };
      command = mkOption {
        default = "";
        description = mdDoc "start command of session";
        type = types.str;
      };
      ignoreDefaultEnvironment = mkOption {
        default = false;
        description = mdDoc "ignore toplevel environment, often useful for shell or irregular sessions";
        type = types.bool;
      };
      environment = mkOption {
        default = {};
        description = mdDoc "environment variables to launch wrapper script with";
        type = types.attrsOf (types.nullOr types.str);
        apply = filterAttrs (_: c: c != null);
      };
      __finalStartCmd = mkOption {
        default = "";
        description = mdDoc "final string to use for command";
        type = types.str;
      };
    };
    config = mkIf config.enable {
      __finalStartCmd = "${mkScript config.session config}";
      environment = if config.ignoreDefaultEnvironment then {} else cfg.defaultEnvironment;
    };
  };

  # swaySession = pkgs.writeTextFile {
  #   name = "sway-session.desktop";
  #   destination = "/sway-session.desktop";
  #   text = ''
  #     [Desktop Entry]
  #     Name=Sway
  #       Exec=$HOME/.winitrc
  #       '';
  # };

  mkSession = scfg: pkgs.writeTextFile {
    name = "${scfg.session}-session.desktop";
    destination = "/${scfg.session}-session.desktop";
    text = ''
      [Desktop Entry]
      Name=${scfg.session}
        Exec=${scfg.__finalStartCmd}
        '';
  };

  # First session is used by default
  sortSessionList = defaultSessionName: sessions:
    [
      sessions.${defaultSessionName}
    ] ++ (attrValues (filterAttrs (_: s: s.session != defaultSessionName) sessions));

  sessionDirs = sessions: builtins.concatStringsSep ":" (
    (map
      mkSession
      (sortSessionList cfg.defaultSession sessions)
    )
  );
in
{
  options.khome.tuigreet = {
    enable = mkOption {
      default = false;
      description = mdDoc "`enable` tuigreet as a display manager.";
      type = types.bool;
    };

    extraArgs = mkOption {
      default = [
        "--remember"
        "--remember-user-session"
        "--time"
        "--user-menu"
        "--asterisks"
      ];
      description = mdDoc "extra args to pass to greetd program";
      type = types.listOf types.str;
    };

    enableGnomeKeyring = mkOption {
      default = true;
      description = mdDoc "enable gnome keyring on login via pam";
      type = types.bool;
    };

    enableWaylandEnvs = mkOption {
      default = false;
      description = mdDoc "sets `defaultEnvironment` to wayland friendly env vars";
      type = types.bool;
    };

    greetdBin = mkOption {
      default = "${pkgs.greetd.tuigreet}/bin/tuigreet";
      description = mdDoc "greetd binary to run";
      type = types.str;
    };

    sessions = mkOption {
      default = {};
      description = mdDoc "launchable desktop environments";
      type = types.attrsOf (types.submodule sessionModule);
    };

    defaultSession = mkOption {
      default = lib.head (lib.attrNames cfg.sessions);
      description = mdDoc "default session for tuigreet, selects first alphabetical of defined sessions if not set";
      type = types.str;
    };

    defaultEnvironment = mkOption {
      default = {};
      description = mdDoc "default environment variables to add to all sessions";
      type = types.attrsOf types.str;
    };

    greeterUser = mkOption {
      default = "greeter";
      description = mdDoc "default user to launch tuigreet with";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    khome.tuigreet.defaultEnvironment = mkIf cfg.enableWaylandEnvs {
      # XDG_SESSION_TYPE = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      NIXOS_OZONE_WL = "1";
      # fcitx5 hacks
      # GTK_IM_MODULE = "fcitx";
      # QT_IM_MODULE = "fcitx";
      # XMODIFIERS = "@im=fcitx";
    };
    khome.tuigreet.sessions = {
      sway = {
        enable = mkDefault false;
        command = "sway";
        environment = {
          # XDG_SESSION_DESKTOP = "sway";
          # XDG_CURRENT_DESKTOP = "sway";
        };
      };
      hyprland = {
        enable = mkDefault false;
        command = "Hyprland";
        environment = {
          # XDG_SESSION_DESKTOP = "Hyprland";
          # XDG_CURRENT_DESKTOP = "Hyprland";
        };
      };
      zsh = {
        enable = mkDefault true;
        command = "zsh";
        ignoreDefaultEnvironment = true;
      };
    };

    users.users.${cfg.greeterUser}.group = cfg.greeterUser;
    users.groups.${cfg.greeterUser} = { };

    systemd.services.display-manager.enable = false;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;
    services.xserver.displayManager.job.execCmd = "";

    security.pam.services.greetd.enableGnomeKeyring = cfg.enableGnomeKeyring;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${cfg.greetdBin} --sessions ${sessionDirs cfg.sessions} ${concatStringsSep " " cfg.extraArgs}";
          user = cfg.greeterUser;
        };
        terminal.vt = 1;
      };
    };
  };
}
