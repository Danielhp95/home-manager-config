{ pkgs, inputs, ... }:
{
  home.file.".config/television/cable/dart.toml".text = ''
    [metadata]
    name = "dart"
    description = "A channel to select dart runs"
    requirements = ["dart"]

    [source]
    command = ["dart run filter | sed -e '1d' -e '$d' | sed -e 's/\"//g' -e 's/,$//'"]

    [preview]
    command = "dart run get --tags {}"
  '';
  programs = {
    television = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
