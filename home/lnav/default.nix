{ pkgs, ... }:

# lnav ignores the terminal palette, so this is a full Ember theme. lnav does
# NOT validate a theme's body: an unknown style key or undefined $var silently
# falls back to the default. Keep the keys equal to the union of the bundled
# themes (written to ~/.config/lnav/configs/default/*.json.sample on first
# run; 43/26/15/4 per section as of 0.14.1) and re-diff after lnav upgrades.
# `vars` reuse the palette's names. semantic() stays unused: it hashes tokens
# into the full 256-colour cube, off-palette.

let
  p = (import ../../palette).hash;

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
      # Every bundled theme only bolds this one
      time-ago.bold = true;
      # The default theme's teal, i.e. the cyan slot, which is sage here
      timeline-bar.background-color = "$sage";
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

    # Syntax highlighting of message bodies, with the terminals' ANSI mapping
    # (kitty/kitty.conf): coral red, olive green, gold yellow, steel blue,
    # mauve magenta, sage cyan.
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
      # The three-band histogram down the left edge, calm -> hot
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
      # Inverted like the fatal level: red text on the coral title would
      # contrast by hue alone, and the two are near-equiluminant
      alert-title = {
        color = "$bg";
        background-color = "$error";
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
      inactive-warn = {
        color = "$gold";
        background-color = "$bgDeep";
      };
      inactive-alert = {
        color = "$error";
        background-color = "$bgDeep";
      };
      suggestion.color = "$muted";
    };

    # Only levels above INFO get a colour, so a screen of INFO lines isn't a
    # wall of hue; fatal inverts, so it survives being skimmed past.
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

  # lnav globs ~/.config/lnav/configs/*/*.json, so the directory name is free.
  # A theme picked at runtime (`:config /ui/theme`) is saved to the writable
  # ~/.config/lnav/config.json and wins over this one.
  xdg.configFile."lnav/configs/ember/config.json".source =
    (pkgs.formats.json { }).generate "lnav-ember.json"
      config;
}
