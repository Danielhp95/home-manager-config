{ pkgs, ... }:

# lnav draws a full-screen log viewer with its own theme system, so it picks up
# nothing from the terminal palette on its own — out of the box it uses the
# built-in "default" theme (blue/cyan status bars, standard 256-colour
# syntax highlighting).
#
# A theme here is a JSON document dropped into
# ~/.config/lnav/configs/<dir>/config.json, which lnav globs at startup. It has
# four style sections, and lnav does NOT validate their contents: an unknown
# style key and a reference to an undefined $var are both accepted in silence,
# and the affected element simply falls back to the default theme. A typo here
# is therefore invisible except as one stubbornly wrong-coloured widget.
#
# The guard against that is to keep this an exact match for the key set in
# lnav's own bundled samples ($out/share/lnav/*.json.sample, also copied to
# ~/.config/lnav/configs/default on first run) — all 41 styles, 26
# syntax-styles, 13 status-styles and 4 log-level-styles, no more and no fewer.
# Diff against those samples after any lnav upgrade that adds a style.
#
# `vars` are arbitrary names substituted wherever a "$name" appears. They are
# deliberately the palette.nix attribute names rather than lnav's usual
# dracula-style colour names, so a reader can diff this against ../palette.nix
# without a translation table in their head.
#
# NOTE lnav's `semantic()` colour function is *not* used, though the upstream
# themes use it for `identifier` and `object-key`. It hashes each token to a
# colour drawn from the full 256-colour cube — only the first 16 of which the
# terminal remaps to Ember — so it is the one lnav feature that reliably emits
# off-palette colour. Swap either style back to { color = "semantic()"; } to
# trade palette discipline for per-identifier distinctness.

let
  p = (import ../palette.nix).hash;

  vars = {
    inherit (p)
      bg
      bgAlt
      bgDeep
      surface
      border
      divider
      fg
      fgDim
      muted
      accent
      accentBright
      gold
      sage
      olive
      steel
      mauve
      error
      ;
  };

  emberTheme = {
    inherit vars;

    styles = {
      identifier.color = "$steel";
      text = {
        color = "$fg";
        background-color = "$bg";
      };
      selected-text = {
        color = "$bg";
        background-color = "$accent";
      };
      fuzzy-match = {
        color = "$accentBright";
        bold = true;
        underline = true;
      };
      # The zebra stripe on alternating log lines.
      alt-text.background-color = "$bgAlt";

      ok = {
        color = "$sage";
        bold = true;
      };
      info = {
        color = "$steel";
        bold = true;
      };
      error = {
        color = "$error";
        bold = true;
      };
      warning = {
        color = "$gold";
        bold = true;
      };
      hidden = {
        color = "$gold";
        bold = true;
      };

      cursor-line = {
        color = "$accentBright";
        background-color = "$surface";
        bold = true;
      };
      disabled-cursor-line = {
        color = "$fgDim";
        background-color = "$bgAlt";
      };
      time-column.background-color = "$bgAlt";
      adjusted-time.color = "$mauve";
      skewed-time.color = "$gold";
      offset-time.color = "$sage";
      file-offset.color = "$muted";
      invalid-msg.color = "$gold";

      focused = {
        color = "$bg";
        background-color = "$fg";
      };
      disabled-focused = {
        color = "$fg";
        background-color = "$surface";
      };
      popup = {
        color = "$fg";
        background-color = "$bgDeep";
      };
      popup-border = {
        color = "$border";
        background-color = "$bgDeep";
      };
      scrollbar = {
        color = "$accent";
        background-color = "$border";
      };

      # Markdown rendering, used by lnav's help and :help output.
      h1 = {
        color = "$accent";
        bold = true;
      };
      h2 = {
        color = "$accent";
        underline = true;
      };
      h3.color = "$accent";
      h4.underline = true;
      h5.italic = true;
      h6.italic = true;
      hr.color = "$border";
      hyperlink.underline = true;
      list-glyph.color = "$sage";
      breadcrumb = {
        color = "$fgDim";
        bold = true;
      };
      table-border.color = "$border";
      table-header.bold = true;
      quote-border = {
        color = "$border";
        background-color = "$bgDeep";
      };
      quoted-text = {
        color = "$olive";
        background-color = "$bgDeep";
      };
      footnote-border = {
        color = "$steel";
        background-color = "$bgDeep";
      };
      footnote-text = {
        color = "$sage";
        background-color = "$bgDeep";
      };
      snippet-border.color = "$sage";
      indent-guide.color = "$divider";
    };

    # Syntax highlighting of message bodies. The hue assignments mirror the
    # ANSI mapping the terminals already use (kitty/kitty.conf colors 0-15):
    # coral is red, olive is green, gold is yellow, steel is blue, mauve is
    # magenta, sage is cyan. A log line therefore highlights the same way
    # whether lnav or a plain `grep --color` renders it.
    syntax-styles = {
      inline-code = {
        color = "$olive";
        background-color = "$bgDeep";
      };
      quoted-code = {
        color = "$gold";
        background-color = "$bgDeep";
      };
      code-border = {
        color = "$border";
        background-color = "$bgDeep";
      };
      object-key.color = "$steel";
      keyword = {
        color = "$accent";
        bold = true;
      };
      string.color = "$olive";
      comment.color = "$muted";
      doc-directive.color = "$mauve";
      variable.color = "$gold";
      symbol.color = "$sage";
      re-special.color = "$sage";
      re-repeat.color = "$gold";
      diff-delete.color = "$error";
      diff-add.color = "$sage";
      diff-section.color = "$steel";
      # The three-band histogram down the left edge. Same calm -> hot ramp as
      # the btop gradients in ../terminal/default.nix.
      spectrogram-low = {
        color = "$bg";
        background-color = "$sage";
        bold = true;
      };
      spectrogram-medium = {
        color = "$bg";
        background-color = "$gold";
        bold = true;
      };
      spectrogram-high = {
        color = "$bg";
        background-color = "$error";
        bold = true;
      };
      file.color = "$steel";
      null.color = "$muted";
      ascii-control.color = "$olive";
      non-ascii.color = "$gold";
      number.bold = true;
      function.color = "$sage";
      separators-references-accessors.color = "$fgDim";
      type.color = "$mauve";
    };

    # The top and bottom status bars.
    status-styles = {
      title = {
        color = "$bg";
        background-color = "$accent";
        bold = true;
      };
      disabled-title = {
        color = "$fgDim";
        background-color = "$bgAlt";
        bold = true;
      };
      subtitle = {
        color = "$bg";
        background-color = "$steel";
        bold = true;
      };
      info = {
        color = "$fgDim";
        background-color = "$bgAlt";
      };
      title-hotkey = {
        color = "$bg";
        background-color = "$accentBright";
        underline = true;
      };
      hotkey = {
        color = "$accentBright";
        underline = true;
      };
      text = {
        color = "$fg";
        background-color = "$bgAlt";
      };
      warn = {
        color = "$gold";
        background-color = "$bgAlt";
      };
      alert = {
        color = "$error";
        background-color = "$bgAlt";
      };
      active = {
        color = "$sage";
        background-color = "$bgAlt";
      };
      inactive = {
        color = "$muted";
        background-color = "$bgDeep";
      };
      inactive-alert = {
        color = "$error";
        background-color = "$bgDeep";
      };
      suggestion.color = "$muted";
    };

    # Only the levels above INFO get a colour; DEBUG/INFO stay in the body
    # colour so that a screen full of INFO lines is not a wall of hue. fatal
    # inverts rather than just brightening, because by then the colour is the
    # only thing that has to survive being skimmed past.
    log-level-styles = {
      warning.color = "$gold";
      error.color = "$error";
      critical = {
        color = "$error";
        bold = true;
      };
      fatal = {
        color = "$bg";
        background-color = "$error";
        bold = true;
      };
    };
  };

  config = {
    "$schema" = "https://lnav.org/schemas/config-v1.schema.json";
    ui = {
      theme = "ember";
      theme-defs.ember = emberTheme;
    };
  };
in
{
  home.packages = [ pkgs.lnav ];

  # lnav globs ~/.config/lnav/configs/*/*.json at startup, so the directory
  # name is free-form; only the theme-defs key has to match `ui.theme`.
  #
  # Setting ui.theme here makes Ember the default, but lnav also persists a
  # theme chosen at runtime (`:config /ui/theme <name>`) into its own writable
  # ~/.config/lnav/config.json, and that file wins. If lnav ever comes up in
  # the wrong theme, that stale runtime override is why.
  xdg.configFile."lnav/configs/ember/config.json".source =
    (pkgs.formats.json { }).generate "lnav-ember.json" config;
}
