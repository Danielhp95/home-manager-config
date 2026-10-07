# wl-kbptr (keyboard-driven pointer) from a newer upstream commit, with two
# patches. Bound as pkgs.wl-kbptr in pkgs/overlay.nix.
{
  wl-kbptr,
  fetchFromGitHub,
}:
wl-kbptr.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "moverest";
    repo = "wl-kbptr";
    rev = "6ef84f398816b7a007ba969047e43d095f332175";
    hash = "sha256-nprdHawJqZK0zL0XcHuxmJquDLPKjl1z0rx5cRbkDe0=";
  };
  patches = (old.patches or [ ]) ++ [
    # Floating mode draws a Vimium-shaped tag at each target's corner
    # (rounded, bold, upper case) instead of a block over the target, with
    # Vimium's glow (../../firefox/vimium-hints.nix, box-shadow) in the hue of
    # selectable_border_color, so it follows the palette.
    ./wl-kbptr-hint-tags.patch
    # Detect targets at the logical resolution on a HiDPI output: about a
    # quarter faster to appear at 3840x2400 @2.
    ./wl-kbptr-logical-detect.patch
  ];
})
