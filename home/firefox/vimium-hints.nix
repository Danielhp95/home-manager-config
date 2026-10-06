# Vimium's link-hint and vomnibar CSS (userDefinedLinkHintCss), in the selected
# palette: hints are accent on a deep ground, the vomnibar is a bgAlt card, and
# the selected row is a wash of the bar's focused workspace pill (noctalia's
# primary role, ../noctalia/material.nix): the solid pill is too stark across a
# full-width row, so it is laid over the card at 25% and the text goes one step
# brighter instead of dark. White stays white for the characters already typed.
#
# The vomnibar's class names are Vimium 2.x's (pages/vomnibar_page.css in the
# xpi); a selector that matches nothing fails silently, and Vimium's own dark
# sheet shows through.
{ theme }:
let
  p = theme;
  h = theme.colour.hash;
  inherit (theme.colour) rgba;
  primary = p.${p.roles.material.primary};
  # The characters already typed: the terminal's paper white.
  white = h p.term.brightWhite;
in
''
  /* Generated from palette/ (firefox/vimium-hints.nix). */

  /* Link hint boxes */
  div > .vimiumHintMarker {
    background: ${h p.bgDeep};
    font-size: 12px;
    border: 0.15em solid ${rgba p.accent "0.35"};
    border-radius: 1.0em;
    box-shadow: 0em 0.1em 0.6em 0.1em ${rgba p.accent "0.2"};
  }

  /* Link hint text */
  div > .vimiumHintMarker span {
    color: ${h p.accent};
    font-size: inherit;
    text-shadow: none;
  }

  #vomnibar {
    border-color: ${rgba p.accent "0.35"};
    background-color: ${h p.bgAlt};
    box-shadow: 0em 0.1em 0.6em 0.1em ${rgba p.accent "0.35"};
  }

  #vomnibar-search-area {
    background-color: ${h p.bgAlt};
    border-bottom: ${rgba p.accent "0.35"};
  }

  #vomnibar li .source {
    color: ${h p.accent};
  }

  #vomnibar input {
    border-color: ${h p.border};
    background-color: ${h p.bgDeep};
    color: ${h p.fg};
  }

  #vomnibar ul {
    background-color: ${h p.bgAlt};
  }

  #vomnibar li {
    border-bottom: ${h p.border};
  }

  #vomnibar li .url {
    color: ${h p.accent};
  }

  #vomnibar li .match {
    color: ${white};
  }

  #vomnibar li em .match, #vomnibar li .title .match {
    color: ${white};
  }

  #vomnibar li em, #vomnibar li .title {
    color: ${h p.fgSoft};
  }

  /* Last: it ties the rules above on specificity and wins on order. */
  #vomnibar li.selected {
    background-color: ${rgba primary "0.25"};
  }

  #vomnibar li.selected :is(.title, em) {
    color: ${h p.fg};
  }

  #vomnibar li.selected :is(.source, .url) {
    color: ${h p.accentBright};
  }

  /* Link hint matching characters */
  div > .vimiumHintMarker > .matchingCharacter {
    color: ${white};
  }
''
