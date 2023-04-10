{pkgs, ...}:
{
  programs.zellij = {
    enable = true;
    package = pkgs.zellij.overrideAttrs ( oldAttrs: { version = "0.35.1"; } );
    # settings = zellijConf;
  };
}
