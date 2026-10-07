# Players and viewers, and what feeds or controls them.
{ pkgs, theme, ... }:
let
  # Bare hex (no leading '#'), the palette's native form.
  pal = theme;
  inherit (theme.colour) argb;
in
{
  programs.mpv = {
    enable = true;
    config = {
      # OSD only: subtitles are content and keep their own colours.
      # `background` is the letterbox (default: a light checkerboard).
      # Colours are AARRGGBB (colour.argb).
      osd-color = argb "FF" pal.fg;
      osd-outline-color = argb "FF" pal.bgDeep;
      osd-back-color = argb "AF" pal.bg;
      background = "color";
      background-color = argb "FF" pal.bgDeep;

      ytdl-format = "bestvideo+bestaudio";
      keep-open = true; # Don't close mpv when video is done
      # VA-API on the iGPU (iHD); auto-safe only uses whitelisted backends.
      hwdec = "auto-safe";
      # libplacebo defaults to the dGPU, but Hyprland composites on the iGPU
      # (AQ_DRM_DEVICES in hyprland.lua), so render there instead of copying
      # every frame across PCIe. The name is Mesa's for this iGPU.
      vulkan-device = "Intel(R) Graphics (ARL)";
    };
  };

  # A flat background instead of imv's default checkerboard, and an Ember
  # status line. imv takes bare hex, the palette's native form.
  programs.imv = {
    enable = true;
    settings.options = {
      background = pal.bgDeep;
      overlay_text_color = pal.fg;
      overlay_background_color = pal.bg;
      overlay_background_alpha = "e0";
    };
  };

  # Bluetooth headset buttons control MPRIS playback.
  services.mpris-proxy.enable = true;

  home.packages = [
    pkgs.ffmpeg # also what yazi's mediainfo previewer shells out to
    pkgs.yt-dlp
    pkgs.gthumb # Viewer for multiple images
    pkgs.playerctl # MPRIS media control, used by hyprland media-key binds
    # Client for the Navidrome server. The server and its login are added in
    # the app and stay in ~/.config/feishin; nothing of them belongs here.
    pkgs.feishin
    # spotify comes from ./spotify.nix; a plain pkgs.spotify would shadow it.
  ];
}
