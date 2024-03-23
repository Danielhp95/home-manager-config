{config, pkgs, lib, home, inputs, ...}:
let
  pathToSaiRepo = "$HOME/Projects/sai";
in
{
  home.packages = with pkgs; [
    git
    inputs.stable.legacyPackages.x86_64-linux.awscli2
    amazon-ecr-credential-helper

    docker
  ];

  # Ensure that credentials are stored in `.netrc`
  home.file.".config/pip/pip.conf".source = ./pip.conf;
  home.file.".docker/config.json".source = ./docker_config.json;
  home.file.".config/sai_docker/config.yaml".source = ./sai_docker_config.yaml;

  home.activation.cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${pathToSaiRepo}" ]; then
      git clone https://github.com/user/repo.git ${pathToSaiRepo}
    fi
 '';
}
