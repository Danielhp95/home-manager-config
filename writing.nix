{pkgs, ...}:
{
  home.packages = with pkgs; [
    texlivePackages.fontspec
    texliveLite
  ];
}
