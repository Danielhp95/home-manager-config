{
  inputs,
  pkgs,
  theme,
  ...
}:

# Spotify (CEF) ignores desktop themes, so spicetify patches its web bundle:
# Sleek with an Ember colour scheme. spicetify installs its own wrapped spotify;
# don't add pkgs.spotify too. A Spotify update can break the patch until
# `nix flake update spicetify-nix`.

let
  p = theme;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.sleek;

    # Behaviour only: vim-style keys, a volume readout, play-next, and
    # word-synced lyrics.
    enabledExtensions = with spicePkgs.extensions; [
      keyboardShortcut
      volumePercentage
      playNext
      spicyLyrics
    ];

    # Sleek's color.ini keys, in bare hex (spicetify adds the '#').
    customColorScheme = {
      text = p.fg;
      subtext = p.fgDim;
      nav-active-text = p.bg;

      main = p.bg;
      main-secondary = p.bgDeep;
      sidebar = p.bgDeep;
      player = p.bgAlt;
      card = p.bgAlt;
      shadow = "000000";

      button = p.accent;
      button-secondary = p.accentDim;
      button-active = p.accentBright;
      button-disabled = p.border;

      nav-active = p.accent;
      play-button = p.accent;
      playback-bar = p.accent;

      tab-active = p.surface;
      notification = p.bgAlt;
      notification-error = p.error;
      misc = p.fg;

      # Not Sleek keys, but spicetify emits them; unset, they fall back to its
      # generic defaults (a pure-white selected row).
      selected-row = p.fg;
      highlight = p.bgAlt;
      highlight-elevated = p.surface;
      main-elevated = p.bgAlt;
    };
  };
}
