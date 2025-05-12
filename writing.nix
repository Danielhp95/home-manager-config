{pkgs, ...}:
{
  home.packages = with pkgs; [
    pandoc
    texlivePackages.fontspec
    texlive.combined.scheme-full
    entr  # Run arbitrary commands when files change
  ];
}
