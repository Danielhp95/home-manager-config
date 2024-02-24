{ pkgs, ... }:

{
  programs.rio = {
    enable = true;
    settings = "./config.toml";
  };
}
