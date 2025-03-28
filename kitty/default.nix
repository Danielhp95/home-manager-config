{ inputs, ... }:

{
  programs.kitty = {
    enable = true;
    package = inputs.unstable.legacyPackages.x86_64-linux.kitty;
    extraConfig = builtins.readFile ./kitty.conf;
    themeFile = "Dracula";
  };
}
