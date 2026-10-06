{ pkgs, ... }:
{
  # pulseaudio only for its CLI tools (pactl & co); pipewire-pulse is the
  # server. Not defaultPackages: assigning that drops perl/rsync/strace.
  environment.systemPackages = with pkgs; [
    pulseaudio
  ];
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
    jack.enable = true;
  };
}
