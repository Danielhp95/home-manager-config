# bat, and man pages through it.
_: {
  # base16 renders through the terminal's ANSI palette, so bat follows the
  # terminal's palette.
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "numbers,changes,header";
    };
  };

  # Man pages through bat's Manpage syntax, in the same ANSI theme. bat cannot
  # read groff's colour escapes: -c makes groff overstrike instead, and col
  # strips that.
  my.liveSessionVariables = [
    "MANPAGER"
    "MANROFFOPT"
  ];
  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };
}
