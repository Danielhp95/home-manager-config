# One colour per kind of file, for everything that lists files: yazi's
# filetype rules (../yazi/default.nix) and LS_COLORS / eza (./ls-colors.nix).
#
# kind -> slot: folders gold and bold (what you navigate by), links sage,
# executables olive, images gold, audio and video mauve, archives the accent,
# a dangling link the error red, struck through.
{
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
}
