{ inputs, pkgs, ... }:

# Spotify is Electron and ignores every desktop theme, so it needs spicetify to
# patch its web bundle. Theme is Sleek (flat, close to WhiteSur's restraint)
# driven by a custom color scheme in the shared Ember palette (./palette.nix).
#
# NOTE spicetify installs its own wrapped spotify into home.packages — plain
# pkgs.spotify must NOT also be installed (see home.nix).
#
# NOTE spicetify patches Spotify's app bundle, so a Spotify update can leave it
# briefly broken until this input is bumped: `nix flake update spicetify-nix`.

let
  p = (import ./palette.nix);
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.sleek;

    # Extensions patch behaviour, not looks — none of these fight Sleek's flat
    # palette. spicyLyrics replaces Spotify's own lyrics pane with a
    # word-synced one; the rest fill in gaps vanilla never had (vim-style
    # navigation, a numeric volume readout, queue-top insertion).
    enabledExtensions = with spicePkgs.extensions; [
      keyboardShortcut
      volumePercentage
      playNext
      spicyLyrics
    ];

    # Sleek's color.ini keys. Values are bare hex — spicetify writes them into
    # an ini and adds the '#' itself.
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

      # Not part of Sleek's own color.ini, but spicetify emits them anyway and
      # would otherwise fall back to its generic dark defaults — including a
      # pure-white selected row.
      selected-row = p.fg;
      highlight = p.bgAlt;
      highlight-elevated = p.surface;
      main-elevated = p.bgAlt;
    };
  };
}
