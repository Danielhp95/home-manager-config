# noctalia's colour roles for a palette. The shell (customPalettes:
# mPrimary-style keys plus a terminal block) and the greeter (snake_case keys)
# both read this, so the two cannot drift.
{ lib }:
let
  # A filled role and the text drawn on it, which is always bg.
  fill = c: role: slot: {
    ${role} = c.${slot};
    "on_${role}" = c.bg;
  };

  # `half` is the palette itself (dark) or its `light`; the role table is the
  # palette's, one for both.
  roles =
    palette: half:
    let
      c = half.hash;
    in
    lib.concatMapAttrs (fill c) palette.roles.material
    // {
      # Its own colour, not the error slot: the shell draws urgent workspaces
      # and notification badges with it, and wants them brighter than the
      # failure red the editors and shells use.
      error = c.extra.urgent;
      on_error = c.bg;
      surface = c.bg;
      on_surface = c.fg;
      surface_variant = c.surface;
      on_surface_variant = c.fgSoft;
      outline = c.border;
      shadow = c.bgDeep;
    };

  # on_surface_variant -> mOnSurfaceVariant
  camel =
    name:
    "m"
    + lib.concatMapStrings (w: lib.toUpper (lib.substring 0 1 w) + lib.substring 1 (-1) w) (
      lib.splitString "_" name
    );

  terminal =
    half:
    let
      c = half.hash;
      t = c.term;
    in
    {
      background = c.bg;
      foreground = c.fg;
      cursor = c.accent;
      cursorText = c.bg;
      selectionBg = c.border;
      selectionFg = c.fg;
      normal = {
        inherit (t)
          black
          red
          green
          yellow
          blue
          magenta
          cyan
          white
          ;
      };
      bright = {
        black = t.brightBlack;
        red = t.brightRed;
        green = t.brightGreen;
        yellow = t.brightYellow;
        blue = t.brightBlue;
        magenta = t.brightMagenta;
        cyan = t.brightCyan;
        white = t.brightWhite;
      };
    };

  shellHalf =
    palette: half:
    lib.mapAttrs' (name: lib.nameValuePair (camel name)) (roles palette half)
    // {
      terminal = terminal half;
    };
in
{
  # The greeter's `appearance.palette` (it is dark only).
  greeter = palette: roles palette palette;
  # A shell custom palette: m* roles drive the shell, `terminal` its terminal
  # templates.
  shell = palette: {
    dark = shellHalf palette palette;
    light = shellHalf palette palette.light;
  };
}
