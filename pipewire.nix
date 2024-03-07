{ lib, ... }:
{
  sound.enable = true;
  # To enable pipewire we need to remove pulseaudio
  hardware.pulseaudio.enable = lib.mkForce false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
    jack.enable = true;
  };
}
