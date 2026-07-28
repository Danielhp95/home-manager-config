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

  mkSession = scfg: pkgs.writeTextFile {
    name = "${scfg.session}-session.desktop";
    destination = "/${scfg.session}-session.desktop";
    text = ''
      [Desktop Entry]
      Name=${scfg.session}
        Exec=${scfg.__finalStartCmd}
        '';
  };

  # Only sessions with enable = true reach the greeter; a disabled session
  # would otherwise still get a desktop entry, with an empty Exec (its
  # __finalStartCmd is only set under mkIf config.enable).
  enabledSessions = filterAttrs (_: s: s.enable) cfg.sessions;

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
  # Ember / WhiteSur-Dark-orange colors (see ./palette.nix). tuigreet parses
  # these with ratatui's Color::from_str, which takes #rrggbb as well as the
  # 16 ANSI color names.
  #
  # NOTE the greeter runs on VT1 (terminal.vt below) and the Linux console
  # cannot display 24-bit color — the kernel approximates each value to the
  # nearest of its 16 palette entries, so this degrades to "coral -> red,
  # graphite -> black" there. The hex is still what we want written down: it is
  # exact whenever the greeter runs inside a real terminal.
  p = (import ./palette.nix).hash;
  themeSpec = concatStringsSep ";" [
    "container=${p.bg}"
    "border=${p.accent}"
    "title=${p.fg}"
    "text=${p.fg}"
    # `greet` styles the whole greeting, pixel art included — Flowey's petals.
    "greet=${p.gold}"
    "time=${p.accent}"
    "prompt=${p.gold}"
    "input=${p.fg}"
    "action=${p.fgDim}"
    "button=${p.accent}"
  ];
  # --greeting takes multi-line text, so it can carry half-block pixel art.
  # greetd doesn't do shell expansion of its command string, so the $(cat ...)
  # has to happen inside a wrapper script.
  #
  # The art must be PLAIN TEXT. tuigreet 0.9.1 — the latest release, and what
  # nixpkgs ships — has no ANSI parser: the greeting goes straight into a
  # ratatui Paragraph, which drops the ESC byte (zero display width) and then
  # draws the rest of each sequence, "[0;30m" and friends, as literal text.
  # ANSI greeting support exists only on upstream master (ansi-to-tui,
  # `greeting.trim().into_text()` in src/ui/util.rs) and has never been
  # released. So the greeting is monochrome, colored by `greet` above; see
  # ./tuigreet_theme/flowey.py, which emits both the .txt we use and a colored
  # .ansi for the day we pin that commit.
  #
  # The theme spec is shell-quoted on BOTH paths. greetd does not tokenize
  # `command` itself — it hands the whole string to `/bin/sh -c` (greetd
  # session/worker.rs: `execve("/bin/sh", ["-c", format!("exec {}", ...)])`), so
  # an unquoted ';'-separated spec is chopped into separate commands by sh and
  # only the first directive ever reaches tuigreet. That is why the old
  # `border=magenta;text=cyan;...` only ever applied its border color.
  greeterCommand =
    if cfg.greetingFile == null then
      "${cfg.greetdBin} --sessions ${sessionDirs enabledSessions} ${concatStringsSep " " cfg.extraArgs} --theme ${lib.escapeShellArg themeSpec}"
    else
      "${pkgs.writeShellScript "tuigreet-with-greeting" ''
        exec ${cfg.greetdBin} --sessions ${sessionDirs enabledSessions} ${concatStringsSep " " cfg.extraArgs} --theme ${lib.escapeShellArg themeSpec} --greeting "$(${pkgs.coreutils}/bin/cat ${cfg.greetingFile})"
      ''}";
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

    greetingFile = mkOption {
      default = null;
      description = mdDoc "file whose contents are shown as the greeting above the login inputs; multi-line plain text (e.g. half-block pixel art), styled with the theme's `greet` color — ANSI escapes are NOT parsed, see the note on greeterCommand";
      type = types.nullOr types.path;
    };

    greetdBin = mkOption {
      default = "${pkgs.tuigreet}/bin/tuigreet";
      description = mdDoc "greetd binary to run";
      type = types.str;
    };

    sessions = mkOption {
      default = {};
      description = mdDoc "launchable desktop environments";
      type = types.attrsOf (types.submodule sessionModule);
    };

    defaultSession = mkOption {
      default = lib.head (lib.attrNames enabledSessions);
      description = mdDoc "default session for tuigreet, selects first alphabetical of enabled sessions if not set";
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
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";  # Tell Qt applications to use the Wayland backend, and fall back to x11 if Wayland is unavailable
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";  # enables automatic scaling, based on the monitor’s pixel density
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
      hyprland = {
        enable = mkDefault false;
        command = "start-hyprland";
        environment = {
          XDG_SESSION_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_CURRENT_DESKTOP = "Hyprland";
          GLFW_IM_MODULE = "fcitx";
          GTK_IM_MODULE = "fcitx";
          INPUT_METHOD = "fcitx";
          XMODIFIERS = "@im=fcitx";
          IMSETTINGS_MODULE = "fcitx";
          QT_IM_MODULE = "fcitx";
          SDL_IM_MODULE = "fcitx";
          GSK_RENDERER = "gl";  # For GSK applications
        };
      };
      gdm = {
        enable = mkDefault false;
        command = "gnome-session";
        environment = {
          XDG_SESSION_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_CURRENT_DESKTOP = "Hyprland";
          GLFW_IM_MODULE = "fcitx";
          GTK_IM_MODULE = "fcitx";
          INPUT_METHOD = "fcitx";
          XMODIFIERS = "@im=fcitx";
          IMSETTINGS_MODULE = "fcitx";
          QT_IM_MODULE = "fcitx";
          SDL_IM_MODULE = "fcitx";
          GSK_RENDERER = "gl";  # For GSK applications
        };

      };
      niri = {
        enable = mkDefault false;
        command = "niri";
        environment = {
          LIBVA_DRIVER_NAME = "nvidia";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          GLFW_IM_MODULE = "fcitx";
          GTK_IM_MODULE = "fcitx";
          INPUT_METHOD = "fcitx";
          XMODIFIERS = "@im=fcitx";
          IMSETTINGS_MODULE = "fcitx";
          QT_IM_MODULE = "fcitx";
          SDL_IM_MODULE = "fcitx";
          GSK_RENDERER = "gl";  # For GSK applications
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
    services.displayManager.gdm.enable = true;

    security.pam.services.greetd.enableGnomeKeyring = cfg.enableGnomeKeyring;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = greeterCommand;
          user = cfg.greeterUser;
        };
        terminal.vt = 1;
      };
    };
  };
}
