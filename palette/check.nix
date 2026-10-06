# The palette's own checks, for `nix flake check`. Build-time and opt-in: a
# wrongly set floor here must not be able to block an evaluation, which the
# schema gate in ./lib.nix would.
{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix) all;
  colour = import ../lib/colour.nix { inherit lib; };

  # ── assets ───────────────────────────────────────────────────────────────
  dirs =
    palette:
    let
      inherit (palette) meta;
    in
    [
      "${meta.gtk.package pkgs}/share/themes/${meta.gtk.name}"
      "${meta.cursor.package pkgs}/share/icons/${meta.cursor.name}/cursors"
      "${meta.icons.package pkgs}/share/icons/${meta.icons.name}"
    ];

  # ── contrast ─────────────────────────────────────────────────────────────
  # WCAG ratios every palette meets today, in both halves unless marked. They
  # pin what is there; they are not a design target. `on` is the ground.
  text = fg: min: {
    inherit fg min;
    on = "bg";
  };
  fill = on: {
    fg = "bg";
    inherit on;
    min = 4.5;
  };
  floors = [
    (text "fg" 7.0)
    (text "fgSoft" 7.0)
    (text "fgDim" 4.5)
    (text "muted" 3.0)
    # Dark text on a filled pill, tab or badge.
    (fill "accent")
    (fill "gold")
    (fill "error")
    (fill "olive")
    (fill "sage")
    (fill "mauve")
    (fill "steel")
    # A dimmer fill on dark only: on paper it is 2.6 by design.
    (
      text "accentDim" 3.0
      // {
        only = "dark";
      }
    )
    # Decorative, not a ground for text: just under 3:1 on dark in both.
    (text "ash" 2.9)
  ];

  rows = lib.concatLists (
    lib.mapAttrsToList (
      slug: palette:
      lib.concatMap
        (
          side:
          let
            half = if side == "dark" then palette else palette.light;
            row =
              what: a: b: min:
              let
                ratio = colour.contrast a b;
              in
              {
                ok = ratio >= min;
                line = "${
                  if ratio >= min then "ok  " else "LOW "
                } ${slug} ${side}: ${what} ${colour.fixed3 ratio}:1 (floor ${colour.fixed3 min})";
              };
          in
          map (f: row "${f.fg} on ${f.on}" half.${f.fg} half.${f.on} f.min) (
            lib.filter (f: (f.only or side) == side) floors
          )
          # noctalia's error role: text and badges on the background.
          ++ [ (row "extra.urgent on bg" half.extra.urgent half.bg 4.5) ]
        )
        [
          "dark"
          "light"
        ]
    ) all
  );
  report = lib.concatMapStringsSep "\n" (r: r.line) rows + "\n";
in
{
  # Builds only if every palette's GTK theme, cursor and icon theme exist
  # under the names its `meta` gives. The schema checks that these are
  # functions and strings; whether the package still exists in nixpkgs, and
  # still ships a theme of that name, only shows when the palette is selected.
  palettes = pkgs.runCommand "palette-assets" { } ''
    ${lib.concatMapStringsSep "\n" (dir: "test -d ${dir} || { echo missing: ${dir}; exit 1; }") (
      lib.concatMap dirs (lib.attrValues all)
    )}
    touch $out
  '';

  # The measured ratios, as the build's output; fails on a row under its floor.
  contrast =
    pkgs.runCommand "palette-contrast"
      {
        inherit report;
        passAsFile = [ "report" ];
      }
      ''
        cat "$reportPath"
        ${lib.optionalString (lib.any (r: !r.ok) rows) "exit 1"}
        cp "$reportPath" $out
      '';
}
