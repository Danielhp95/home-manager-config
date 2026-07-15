{ ... }:
{
  # Salt minion for Sony AI infrastructure (see sony_ai/).
  # NixOS-level because salt-minion runs as a system daemon; it cannot live in
  # the home-manager config (services.salt.* is not a home-manager option).
  services.salt.minion.enable = true;
}
