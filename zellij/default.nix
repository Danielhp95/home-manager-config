let
  zellijConf = builtins.readFile ./zellij.conf;
in
{
  programs.zellij = {
    enable = true;
    settings = zellijConf;
  };
}
