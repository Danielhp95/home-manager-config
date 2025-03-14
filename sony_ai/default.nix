{pkgs, lib, home, inputs, stableWithUnfree, ...}:
let
  pathToSaiRepo = "$HOME/Projects/sai";
in
{
  home.packages = with pkgs; [
    git
    awscli2
    amazon-ecr-credential-helper

    docker

    # stableWithUnfree.steam-run
    steam-run  # To run proton via Steam's FHS

    (writeShellScriptBin "sie-vpn-connect" ''
    sudo ${pkgs.openconnect}/bin/openconnect --protocol nc la.vpn.sie.sony.com/cgei
  '')
  ];

  # Ensure that credentials are stored in `.netrc`
  # home.file.".config/pip/pip.conf".source = ./pip.conf;
  # home.file.".config/pypoetry/auth.toml".source = ./poetry_auth.toml;

  home.file.".docker/config.json".source = ./docker_config.json;
  home.file.".config/sai_docker/config.yaml".source = ./sai_docker_config.yaml;

  # environment.etc."fixuid/config.yml".source = ./fixuid_config.yml
  home.activation.cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${pathToSaiRepo}" ]; then
      git clone https://github.com/user/repo.git ${pathToSaiRepo}
    fi
 '';
}
