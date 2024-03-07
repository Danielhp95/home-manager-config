{ config, lib, pkgs, ... }:

with lib;
let
  base = builtins.readFile ./sway_i3_shared.conf;
  wayland.windowManager.sway = {
    enable = true;
    extraConfig = base + powerOffMode + screenshotMode +
      ''output "*" bg $HOME/Pictures/hangmoon/purple-blue-meadow-couple-sitting.jpg fill''; # Sets wallpaper on all outputs
    # extraOptions = [ "--unsupported-gpu" ];
    wrapperFeatures.gtk = true;
    config = {
      modifier = "Mod4";
      terminal = "wezterm";
      fonts = {
        names = [ "FontAwesome 13" ];
        style = "Bold Semi-Condensed";
        size = 13.0;
      };
      menu = ''rofi -show-icons -modi "drun,run" -show drun'';
      gaps = {
        inner = 4;
        outer = -2;
        smartGaps = true;
        smartBorders = "on";
      };
      # TODO: assigns don't work
      assigns = {
        "2" = [
          { class = "Firefox$"; }
        ];
        "9" = [
          { class = "Signal"; }
          { class = "telegramdesktop"; }
          { class = "element"; }
        ];
      };
      focus.newWindow = "urgent";
      # TODO: floating doesn't work
      floating = {
        criteria = [
          { class = "Pavucontrol"; }
        ];
      };
      modes = {
        resize = {
          # escape modes
          Escape = "mode default";
          Return = "mode default";
          # arrow keys resize
          Up = "resize shrink height 10 px";
          Down = "resize grow height 10 px";
          Left = "resize shrink width 10 px";
          Right = "resize grow width 10 px";
          # hjkl resize
          k = "resize shrink height 10 px";
          j = "resize grow height 10 px";
          h = "resize shrink width 10 px";
          l = "resize grow width 10 px";
        };
      };
      keybindings = mkOptionDefault ({
        # Rofi
        "${mod}+Shift+o" = "exec --no-startup-id rofi -show file-browser-extended";
        "${mod}+Shift+b" = "exec --no-startup-id bash ~/config/users/profiles/desktop/rofi/scripts/choose_bluetooth_device_from_paired.sh";
        "${mod}+Shift+p" = "exec --no-startup-id bash ~/config/users/profiles/desktop/rofi/scripts/open_paper.sh";

        # Put on scratchpad which maximes a 1080p screen
        "${mod}+Shift+n" = "move scratchpad, scratchpad show, resize set 1912 1043, move position 4 4";

        # bind brightnessctl to function keys
        # TODO: Show brightness levels on notification
        "XF86MonBrightnessUp" = "exec brightnessctl set 5+%";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "Shift+XF86MonBrightnessDown" = "exec brightnessctl set 1%";
        "Shift+XF86MonBrightnessUp" = "exec brightnessctl set 100%";

        # Pulse Audio controls
        "XF86AudioRaiseVolume" = "exec --no-startup-id pamixer -i 5"; # increase sound volume
        "XF86AudioLowerVolume" = "exec --no-startup-id pamixer -d 5"; # decrease sound volume
        "XF86AudioMute" = "exec --no-startup-id pamixer --toggle-mute"; # mute sound
        "${mod}+Shift+m" = "exec pavucontrol";

        # Media control
        "XF86AudioPlay" = "exec --no-startup-id playerctl play-pause";
        "XF86AudioNext" = "exec --no-startup-id playerctl next";
        "XF86AudioPrev" = "exec --no-startup-id playerctl previous";

        # Moving workspaces around
        "${mod}+Control+Shift+Right" = "move workspace to output right";
        "${mod}+Control+Shift+Left" = "move workspace to output left";
        "${mod}+Control+Shift+Down" = "move workspace to output down";
        "${mod}+Control+Shift+Up" = "move workspace to output up";
      });
      input = {
        "*" = {
          xkb_layout = "gb";
          xkb_options = "caps:escape";
          tap = "enabled";
        };
      };
      startup = [
        { command = "exec mako"; always = true; }
        { command = "systemctl --user restart waybar"; always = true; }
        { command = "systemctl --user restart kanshi"; always = true; }
        { command = "dbus-update-activation-environment --systemd DISPLAY"; always = true; } # Chris hack for something
        { command = "echo XHC | sudo tee /proc/acpi/wakeup"; always = true; } # RAZER BLADE 2018 usb wakeup FIX:
        { command = "tmux start-server"; always = true; }
        {
          # locks screen after 5 mins + turns off/on monitors
          always = true;
          command = ''
            exec swayidle -w \
              timeout 300 'swaylock -f' \
                timeout 300 'swaymsg "output * dpms off"' \
                  resume 'swaymsg "output * dpms on"' \
                    before-sleep 'swaylock -f'
          '';
        }
      ];
      # waybar is configured separately
      # This has to be empty to disable ugly default bar at the bottom
      bars = [ ];
    };
  };
  powerOffMode = ''
    set $mode_system (l)ock, (e)xit, switch_(u)ser, (s)uspend, (h)ibernate, (r)eboot, (Shift+s)hutdown
    bindsym $mod+0 mode "$mode_system"
    mode "$mode_system" {
        bindsym l exec --no-startup-id swaylock lock, mode "default"
        bindsym s exec --no-startup-id systemctl suspend, mode "default"
        bindsym u exec --no-startup-id i3exit switch_user, mode "default"
        bindsym e exec --no-startup-id i3exit logout, mode "default"
        bindsym h exec --no-startup-id systemctl hibernate, mode "default"
        bindsym r exec --no-startup-id systemctl reboot, mode "default"
        bindsym Shift+s exec --no-startup-id systemctl poweroff, mode "default"

        # exit system mode: "Enter" or "Escape"
        bindsym Return mode "default"
        bindsym Escape mode "default"
    }
  '';
  screenshotMode = ''
    set $mode_screenshot Shift to copy (a)area select, (t)arget window (s)screen
    bindsym $mod+ctrl+s mode "$mode_screenshot"
    mode "$mode_screenshot" {
      bindsym a exec --no-startup-id grimshot save area   "$HOME/Pictures/screenshots/$(date +%d-%m-%y_%T).png", mode "default"
      bindsym s exec --no-startup-id grimshot save screen "$HOME/Pictures/screenshots/$(date +%d-%m-%y_%T).png" , mode "default"
      bindsym t exec --no-startup-id grimshot save window "$HOME/Pictures/screenshots/$(date +%d-%m-%y_%T).png", mode "default"
      bindsym Shift+a exec --no-startup-id grimshot copy area, mode "default"
      bindsym Shift+s exec --no-startup-id grimshot copy screen, mode "default"
      bindsym Shift+t exec --no-startup-id grimshot copy window, mode "default"
      bindsym Return mode "default"
      bindsym Escape mode "default"
    }
  '';
  mod = config.wayland.windowManager.sway.config.modifier;
  # TODO: change this
  # sway uses `app_id` instead of `class` for app identification
  criteriaRewrite = criteria: builtins.removeAttrs
    (criteria // {
      app_id = criteria.class;
    }) [ "class" ];
in
{
  home.packages = with pkgs; [
    swayidle # Autolock
    swaybg # To set wallpapers
    swww # To set better wallpapers
    wdisplays # Display management
    wl-clipboard # Clipboard managment

    sway-contrib.grimshot # screenshots

    brightnessctl # Controlling screen brightness
    fcitx5 # Multi-language keyboard support
    pamixer # Controlling volume. Mixer for pipewire

    libnotify # Library to allow notifications
  ];

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
    SDL_VIDEODRIVER = "wayland";
    # TODO: maybe move these to their own keyboard setting profile?
    GTK_IM_MODULE = "fcitx5";
    QT_IM_MODULE = "fcitx5";
    XDG_SCREENSHOTS_DIR = "$HOME/Pictures/screenshots"; # This makes grim run from the commandline work, but not when used here!
    SSH_ASKPASS = ""; # To remove annoying GUI showing up everytime one git pushes
  };
}
