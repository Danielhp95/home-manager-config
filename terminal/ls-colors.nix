{ lib, ... }:

# One colour per kind of file for everything that lists files outside yazi:
# LS_COLORS (ls, fd, the zsh completion menu, nushell's ls) and eza's theme.
# The kinds and their slots are yazi's filetype rules (../yazi/default.nix);
# keep the two in step.
#
# A slot that is one of the terminal's 16 colours is written as that ANSI
# slot, so it follows whatever palette the terminal has (the Linux console
# included, which cannot draw hex); any other slot falls back to truecolor.
let
  palette = import ../palette;
  colour = import ../lib/colour.nix { inherit lib; };

  # kind -> slot, as in yazi: folders gold and bold (what you navigate by),
  # links sage, executables olive, images gold, audio and video mauve,
  # archives the accent, a dangling link the error red, struck through.
  kinds = {
    dir = {
      slot = "gold";
      bold = true;
    };
    link.slot = "sage";
    orphan = {
      slot = "error";
      strike = true;
    };
    exec.slot = "olive";
    # Pipes, sockets and devices: yazi has no rule for them.
    special.slot = "steel";
    image.slot = "gold";
    media.slot = "mauve";
    archive.slot = "accent";
  };

  extensions = {
    image = [
      "avif"
      "bmp"
      "gif"
      "heic"
      "heif"
      "ico"
      "jpeg"
      "jpg"
      "jxl"
      "png"
      "psd"
      "svg"
      "tif"
      "tiff"
      "webp"
      "xcf"
    ];
    media = [
      "aac"
      "avi"
      "flac"
      "m4a"
      "m4v"
      "mka"
      "mkv"
      "mov"
      "mp3"
      "mp4"
      "mpeg"
      "mpg"
      "oga"
      "ogg"
      "ogv"
      "opus"
      "wav"
      "webm"
      "wma"
      "wmv"
    ];
    archive = [
      "7z"
      "bz2"
      "cab"
      "cpio"
      "gz"
      "lzma"
      "rar"
      "tar"
      "tbz2"
      "tgz"
      "txz"
      "xz"
      "zip"
      "zst"
    ];
  };

  # A slot's place among the 16 ANSI colours, or null.
  ansiIndex = slot: lib.lists.findFirstIndex (c: c == palette.${slot}) null palette.ansi;

  # ── SGR parameters (LS_COLORS) ───────────────────────────────────────────
  # `base` is 30 for a foreground, 40 for a background.
  sgrColour =
    base: slot:
    let
      i = ansiIndex slot;
    in
    if i == null then
      "${toString (base + 8)};2;${colour.rgbSemicolons palette.${slot}}"
    else
      toString (if i < 8 then base + i else base + 52 + i);

  sgr =
    {
      slot,
      bold ? false,
      underline ? false,
      strike ? false,
    }:
    lib.concatStringsSep ";" (
      lib.optional bold "1"
      ++ lib.optional underline "4"
      ++ lib.optional strike "9"
      ++ [ (sgrColour 30 slot) ]
    );

  # Dark text on a filled slot, like the prompt's error pill.
  slab = slot: "${sgrColour 30 "bg"};${sgrColour 40 slot}";

  lsColors = lib.concatStringsSep ":" (
    lib.mapAttrsToList (code: style: "${code}=${style}") {
      di = sgr kinds.dir;
      ln = sgr kinds.link;
      "or" = sgr kinds.orphan;
      # The missing target `ls -l` prints after a dangling link's arrow.
      mi = sgr { inherit (kinds.orphan) slot; };
      ex = sgr kinds.exec;
      pi = sgr kinds.special;
      so = sgr kinds.special;
      bd = sgr (kinds.special // { bold = true; });
      cd = sgr (kinds.special // { bold = true; });
      # setuid and setgid programs keep the warning that dircolors gives them.
      su = slab "error";
      sg = slab "gold";
      # Directories: sticky ones are ordinary, world-writable ones underlined
      # (dircolors paints these as green blocks).
      st = sgr kinds.dir;
      ow = sgr (kinds.dir // { underline = true; });
      tw = sgr (kinds.dir // { underline = true; });
    }
    ++ lib.concatLists (
      lib.mapAttrsToList (kind: map (ext: "*.${ext}=${sgr kinds.${kind}}")) extensions
    )
  );

  # ── eza's theme ──────────────────────────────────────────────────────────
  # eza obeys LS_COLORS first; the theme covers a shell without the variable,
  # and takes the colour off eza's own classes that yazi has no rule for
  # (its source files are bold yellow, which is what a directory is here).
  ansiNames = [
    "Black"
    "Red"
    "Green"
    "Yellow"
    "Blue"
    "Purple"
    "Cyan"
    "White"
    "DarkGray"
    "LightRed"
    "LightGreen"
    "LightYellow"
    "LightBlue"
    "LightPurple"
    "LightCyan"
    "LightGray"
  ];

  # Every attribute is stated: an entry merges into eza's default for that
  # key, so an omitted `is_bold` would keep the default's.
  ezaStyle =
    {
      slot ? null,
      bold ? false,
      underline ? false,
      strike ? false,
    }:
    {
      foreground =
        if slot == null then
          "Default"
        else if ansiIndex slot == null then
          palette.hash.${slot}
        else
          builtins.elemAt ansiNames (ansiIndex slot);
      is_bold = bold;
      is_dimmed = false;
      is_underline = underline;
      is_strikethrough = strike;
    };
  plain = ezaStyle { };
in
{
  # Literal, not read from a file at login: nushell loads session variables
  # unexpanded. zsh restates it per shell and re-reads it after a palette
  # switch (../zsh/default.nix).
  home.sessionVariables.LS_COLORS = lsColors;

  programs.eza.theme = {
    filekinds = {
      directory = ezaStyle kinds.dir;
      mount_point = ezaStyle (kinds.dir // { underline = true; });
      symlink = ezaStyle kinds.link;
      executable = ezaStyle kinds.exec;
      pipe = ezaStyle kinds.special;
      socket = ezaStyle kinds.special;
      block_device = ezaStyle (kinds.special // { bold = true; });
      char_device = ezaStyle (kinds.special // { bold = true; });
    };
    file_type = {
      image = ezaStyle kinds.image;
      video = ezaStyle kinds.media;
      music = ezaStyle kinds.media;
      lossless = ezaStyle kinds.media;
      compressed = ezaStyle kinds.archive;
      crypto = plain;
      document = plain;
      temp = plain;
      compiled = plain;
      build = plain;
      source = plain;
    };
    broken_symlink = ezaStyle kinds.orphan;
  };
}
