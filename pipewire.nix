{ lib, pkgs, ... }:
{
  # The pulseaudio *package* is only here for its CLI tools (pactl & co) —
  # the server itself is pipewire-pulse below.
  # NOTE: this must be systemPackages. defaultPackages is the small curated
  # NixOS default set (perl, rsync, strace) meant to be *overridden to remove*
  # those; assigning extra packages to it silently dropped strace and perl
  # from the system.
  environment.systemPackages = with pkgs; [
    pulseaudio
  ];
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    wireplumber.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };
}
