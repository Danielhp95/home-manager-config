{ ... }:

{
  programs.ghostty = {
    enable = true;
    extraConfig = builtins.readFile ./config;
  };
}

