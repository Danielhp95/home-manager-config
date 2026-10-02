# Vimium's link-hint and vomnibar CSS (userDefinedLinkHintCss), in the selected
# palette: hints are accent on a deep ground, the vomnibar is a bgAlt card, and
# the selected row is the accent at a quarter strength so its text keeps
# contrast. White stays white for the characters already typed.
{ lib, p }:
let
  h = c: "#${c}";
  # rgba() takes decimal channels; the palette is bare hex.
  rgba =
    c: a:
    let
      ch = i: toString (lib.fromHexString (builtins.substring (2 * i) 2 c));
    in
    "rgba(${ch 0}, ${ch 1}, ${ch 2}, ${a})";
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

  input#vomnibarInput.vimiumReset {
    color: ${h p.fg} !important;
    background-color: ${h p.bgDeep} !important;
  }

  #vomnibar {
    border-color: ${rgba p.accent "0.35"};
    background-color: ${h p.bgAlt};
    box-shadow: 0em 0.1em 0.6em 0.1em ${rgba p.accent "0.35"};
  }

  #vomnibar .vomnibarSearchArea {
    background-color: ${h p.bgAlt};
    border-bottom: ${rgba p.accent "0.35"};
  }

  #vomnibar li .vomnibarTopHalf .vomnibarSource {
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

  #vomnibar li .vomnibarUrl {
    color: ${h p.accent};
  }

  #vomnibar li .vomnibarMatch {
    color: #ffffff;
  }

  #vomnibar li.vomnibarSelected {
    background-color: ${rgba p.accent "0.25"};
  }

  #vomnibar li em .vomnibarMatch, #vomnibar li .vomnibarTitle .vomnibarMatch {
    color: #ffffff;
  }

  #vomnibar li em, #vomnibar li .vomnibarTitle {
    color: ${h p.fgSoft};
  }

  /* Link hint matching characters */
  div > .vimiumHintMarker > .matchingCharacter {
    color: #ffffff;
  }
''
