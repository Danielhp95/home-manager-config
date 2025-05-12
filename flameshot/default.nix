{ pkgs, ... }:
{
  # Hopefully this will work at some point
  services.flameshot = {
    enable = true;
    package = (pkgs.flameshot.override { enableWlrSupport = true;});
    settings.General = {
      showStartupLaunchMessage = false;
      saveLastRegion = false;
    };
  };
}
