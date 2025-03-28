# Instructions from (https://gist.github.com/nilsherzig/78314c9075a53a5b461f2713d9e54476)
# Copy your binaries (.deb package) to /opt/CrowdStrike.
# Add both .nix files from this page to your config.
# Write your companies ID to /etc/falcon-sensor.env in the format of COMPANYID="[id]".
# Apply nixos update.
# Check sensor status using systemctl status falcon-sensor (should be running if the nixos update succeeded)
{
  # inputs,
  dpkg,
  stdenv,
  lib,
  openssl,
  libnl,
  zlib,
  autoPatchelfHook,
  buildFHSUserEnv,
  ...
}:
let
  pname = "falcon-sensor";
  version = "7.22.0-17507";
  arch = "amd64";
  src = /opt/CrowdStrike + "/${pname}_${version}_${arch}.deb";
  falcon-sensor = stdenv.mkDerivation {
    inherit version arch src;
    name = pname;

    nativrBuildInputs = [ dpkg ];
    buildInputs = [
      # inputs.unstable.legacyPackages.x86_64-linux.dpkg
      dpkg
      zlib
      autoPatchelfHook
    ];

    sourceRoot = ".";

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      cp -r . $out
    '';

    meta = with lib; {
      description = "Crowdstrike Falcon Sensor";
      homepage = "https://www.crowdstrike.com/";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ ] ;
    };
  };
in
buildFHSUserEnv {
  name = "fs-bash";
  targetPkgs = pkgs: [
    libnl
    openssl
    zlib
  ];

  extraInstallCommands = ''
    ln -s ${falcon-sensor}/* $out/
  '';

  runScript = "bash";
}
