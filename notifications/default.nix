{ pkgs, ... }:
{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];
  # https://manpages.ubuntu.com/manpages/noble/man5/swaync.5.html
  services.swaync = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./swaync/config.json);
    style = ./swaync/style.css;
  };
}
