# Palette slots (bare hex, palette/ shape) -> libadwaita / adw-gtk3 named colours.
# Returns { css3; css4; } for gtk.gtk3.extraCss / gtk.gtk4.extraCss.
# Works on any theme whose stylesheet REFERENCES the names (adw-gtk3, libadwaita itself);
# it does nothing useful on WhiteSur / Tokyonight, whose CSS is compiled to literal hex.
p:
let
  # Both take a half of the palette and read its '#' view.
  named =
    { hash, ... }:
    ''
      /* accent: filled controls and standalone text/links alike; the brighter step sits too
         close to window text to read as a link */
      @define-color accent_bg_color ${hash.accent};
      @define-color accent_fg_color ${hash.bg};
      @define-color accent_color ${hash.accent};

      /* status: error = failures, olive = success, gold = warnings */
      @define-color destructive_bg_color ${hash.error};
      @define-color destructive_fg_color ${hash.bg};
      @define-color destructive_color ${hash.error};
      @define-color error_bg_color ${hash.error};
      @define-color error_fg_color ${hash.bg};
      @define-color error_color ${hash.error};
      @define-color success_bg_color ${hash.olive};
      @define-color success_fg_color ${hash.bg};
      @define-color success_color ${hash.olive};
      @define-color warning_bg_color ${hash.gold};
      @define-color warning_fg_color ${hash.bg};
      @define-color warning_color ${hash.gold};

      /* surfaces: bg = window, bgDeep = sunken (views, sidebars), bgAlt = raised chrome
         (headerbars, cards, dialogs), surface = floating (popovers, thumbnails) */
      @define-color window_bg_color ${hash.bg};
      @define-color window_fg_color ${hash.fg};
      @define-color view_bg_color ${hash.bgDeep};
      @define-color view_fg_color ${hash.fg};
      @define-color headerbar_bg_color ${hash.bgAlt};
      @define-color headerbar_fg_color ${hash.fg};
      @define-color headerbar_border_color ${hash.fg};
      @define-color headerbar_backdrop_color ${hash.bg};
      @define-color sidebar_bg_color ${hash.bgDeep};
      @define-color sidebar_fg_color ${hash.fg};
      @define-color sidebar_backdrop_color ${hash.bgDeep};
      @define-color sidebar_border_color ${hash.border};
      @define-color secondary_sidebar_bg_color mix(${hash.bgDeep}, ${hash.bg}, 0.5);
      @define-color secondary_sidebar_fg_color ${hash.fg};
      @define-color secondary_sidebar_backdrop_color mix(${hash.bgDeep}, ${hash.bg}, 0.5);
      @define-color secondary_sidebar_border_color ${hash.border};
      @define-color card_bg_color ${hash.bgAlt};
      @define-color card_fg_color ${hash.fg};
      @define-color dialog_bg_color ${hash.bgAlt};
      @define-color dialog_fg_color ${hash.fg};
      @define-color popover_bg_color ${hash.surface};
      @define-color popover_fg_color ${hash.fg};
      @define-color thumbnail_bg_color ${hash.surface};
      @define-color thumbnail_fg_color ${hash.fg};
    '';
  # Required, not decoration: adw-gtk3's libadwaita-tweaks.css hard-wires
  # `--accent-bg-color: var(--accent-blue)` for plain GTK4 apps (verified: blue controls
  # without this), and libadwaita derives --accent-color from --accent-bg-color in oklab.
  root =
    { hash, ... }:
    ''
      :root {
        --accent-bg-color: ${hash.accent};
        --accent-fg-color: ${hash.bg};
        --accent-color: ${hash.accent};
      }
    '';
  indent = s: builtins.replaceStrings [ "\n" ] [ "\n  " ] s;
in
{
  # GTK3 (adw-gtk3-dark) and, through QT_QPA_PLATFORMTHEME=gtk3, Qt6. GTK3 CSS has no
  # media queries and theming.nix pins gtk3.colorScheme = "dark": dark half only.
  css3 = named p;

  # GTK4: libadwaita apps, and plain GTK4 apps drawn with adw-gtk3's gtk-4.0 sheet.
  # The light half rides on the dconf color-scheme key that noctalia's toggle flips.
  css4 =
    named p
    + root p
    + (
      if p ? light then
        ''
          @media (prefers-color-scheme: light) {
            ${indent (named p.light + root p.light)}
          }
        ''
      else
        ""
    );
}
