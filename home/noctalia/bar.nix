# The bar and its widgets.
{ lib, pkgs, ... }:
let
  volume = lib.getExe pkgs.volume-all-sinks;
in
{
  home.packages = [ pkgs.volume-all-sinks ];

  programs.noctalia.settings = {
    # Floating pills: a transparent bar (its shadow scales with
    # background_opacity, so it has none) with every widget in its own
    # capsule. Must be named "default" to replace the built-in bar; any other
    # name adds a second one.
    bar.default = {
      position = "top";
      thickness = 36;
      background_opacity = 0.0;
      # No protocol blur behind the bar: the pills are opaque, and the gaps
      # between them stay clear. noctalia asks the compositor to blur the
      # whole bar rect (ext-background-effect-v1), which Hyprland's layer
      # rules can't switch off; this drops the request itself (5.2.1).
      # https://docs.noctalia.dev/noctalia/bar/ ("compositor_blur")
      compositor_blur = false;
      radius = 18;
      margin_ends = 8; # inset from each end of the bar
      # margin_edge: gap above; margin_opposite_edge: gap below, taken from
      # the reserved space. 6/0 sat a pixel low.
      margin_edge = 5;
      margin_opposite_edge = 1;
      padding = 12;
      widget_spacing = 8;
      shadow = true;
      capsule = true;
      capsule_fill = "surface_variant";
      capsule_opacity = 1.0;
      # Fraction of bar thickness (default 0.76); the pills are the whole bar.
      capsule_thickness = 0.88;

      # One pill per widget, except the capsule_groups below.
      start = [
        "group:clockweather"
        "active_window"
        "media"
      ];
      center = [
        "privacy"
        "workspaces"
        "dart"
      ];
      end = [
        "group:tray"
        "group:volbright"
        "group:sysmon"
      ];

      capsule_group = [
        {
          id = "clockweather";
          members = [
            "clock"
            "weather"
          ];
          fill = "surface_variant";
        }
        {
          id = "tray";
          members = [
            "tray"
            "tailnet"
            "notifications"
          ];
          fill = "surface_variant";
        }
        {
          id = "volbright";
          members = [
            "bluetooth"
            "volume"
            "brightness"
          ];
          fill = "surface_variant";
        }
        {
          id = "sysmon";
          members = [
            "sysmon"
            "ram"
            "gpu"
            "vram"
            "battery"
          ];
          fill = "surface_variant";
        }
      ];
    };

    widget = {
      # Names (nerdfont glyphs, set in hyprland.lua) instead of numbers.
      workspaces = {
        label_source = "name";
        show_labels = true;
        # Other monitors' active workspaces fall back to occupied_color.
        focused_output_only = true;
      };

      # Never set `anchor` here (the settings GUI can save one): an anchored
      # widget splits off the clockweather pill.
      clock = {
        format = "{:%H:%M %a, %b %d}";
        tooltip_format = "{:%A, %B %d, %Y}";
      };

      weather = {
        show_temperature = true;
        show_condition = true;
      };

      # Scrolling steps every output (volume-all-sinks); the label and clicks
      # still follow the default sink.
      volume = {
        actions.scroll_up = "exec ${volume} 5%+";
        actions.scroll_down = "exec ${volume} 5%-";
      };

      sysmon = {
        stat = "cpu_usage";
      };

      ram = {
        type = "sysmon";
        stat = "ram_pct";
      };

      # dGPU load and VRAM over NVML (the iGPU exposes neither); VRAM idles
      # at ~2%, the driver's reserve. Polling costs no D3 sleep: Hyprland
      # holds /dev/nvidia0 open anyway. Own glyphs: the default vram icon is
      # ram's.
      gpu = {
        type = "sysmon";
        stat = "gpu_usage";
        glyph = "cube";
      };
      vram = {
        type = "sysmon";
        stat = "gpu_vram";
        glyph = "stack-2";
      };

      bluetooth = {
        show_label = true;
        hide_when_no_connected_device = false;
      };

      tray = {
        hide_passive = true;
        drawer = true;
        pinned = [
          "Fcitx"
          "Slack_status_icon_1"
          "Element_status_icon_1"
          "org.twosheds.iwgtk"
        ];
      };

      # Mic / camera / screencast indicator; the screen recorder and xdph
      # screencasts show no other sign.
      privacy = {
        hide_inactive = true;
      };

      # Aliases: a bare "dart" in the bar lanes resolves through these to the
      # plugin's widget entry.
      dart = {
        type = "dani/dart:widget";
      };

      tailnet = {
        type = "rylos/tailnet:bar";
      };
    };
  };
}
