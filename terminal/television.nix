{ pkgs, inputs, ... }:
{
  home.file.".config/television/cable/dart.toml".text = ''
    [metadata]
    name = "dart"
    description = "A channel to select dart runs"
    requirements = ["dart"]

    [source]
    command = ["dart search --username-substrings daniel.hernandez"]

    [preview]
    command = "dart run get --config {0}"
  '';
  programs = {
    television = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
