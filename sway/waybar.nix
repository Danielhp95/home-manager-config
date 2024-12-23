{ config, pkgs, inputs, ... }:

{
  programs.waybar = {
    enable = true;
    # Let's have each window manager launch this on its own
    # Otherwise this only kicks in upon boot, and not upon loging in-out
    systemd.enable = true;
    package = pkgs.waybar;
    # TODO: style
    style = ./waybar_style.css;
    settings = {
      mainbar = {
        layer = "top";
        position = "top";
        height = 35;
        modules-left = [ "clock" "idle_inhibitor" ];
        modules-center = [ "sway/workspaces" "hyprland/workspaces" "sway/mode" ];
        # modules-right = [ "pulseaudio" "network" "cpu" "memory" "disk" "temperature" "backlight" "battery" "tray" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "disk" "temperature" "backlight" "tray" ];
        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
        };
        "hyprland/workspaces" = {
           sort-by-number=true;
           format= "{icon}";
           on-scroll-up = "hyprctl dispatch workspace e+1";
           on-scroll-down = "hyprctl dispatch workspace e-1";
        };
        # "battery" = {
        #   format = "{capacity}% {icon}";
        #   format-icons = [ "" "" "" "" "" ];
        #   states = {
        #     critical = 15;
        #     warning = 30;
        #   };
        # };
        "sway/mode" = {
          format = "<span style =\"italic\">{}</span>";
        };
        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            "activated" = "";
            "deactivated" = "";
          };
        };
        "clock" = {
          # TODO: figure out system-level options in home-manager
          #timezone = config.time.timeZone;
          #locale = config.i18n.defaultLocale;
          #timezone = "Europe/Amsterdam";
          #timezone = "Europe/London";
          locale = "en_US.UTF-8";
          format = "{:%H:%M:%S}";
          format-alt = "{:%H:%M:%S   %Y-%m-%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          interval = 1;
        };
        "cpu" = {
          format = "{usage}% ";
          #tooltip = false;
        };
        "disk" = {
          interval = 30;
          format = "{used} / {total}";
          path = "/";
        };
        "memory" = {
          interval = 10;
          format = "{used:0.1f}G / {total:0.1f}G ";
        };
        "temperature" = {
          # "thermal-zone" = 2;
          # TODO: need to figure out how to change this easily per system
          hwmon-path = "/sys/class/hwmon/hwmon4/temp1_input";
          critical-threshold = 80;
          format-critical = "<span style=\"bold\"> CRITICAL: {temperatureC}°C {icon}</span>";
          format = " {temperatureC}°C {icon}";
          format-icons = [ "" "" "" ];
        };
        "backlight" = {
          device = "acpi_video1";
          format = "{percent}% {icon}";
          format-icons = [ "" "" ];
        };
        "network" = {
          # "interface" = "wlp2*", // (Optional) To force the use of this interface
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ifname} = {ipaddr}/{cidr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname} = {ipaddr}/{cidr}";
        };
        "pulseaudio" = {
          scroll-step = 1;
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          # No need for microphone
          # format-source = "{volume}% ";
          # format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
        "tray" = {
            icon-size = 21;
            spacing = 10;
          };
      };
    };
  };
}
