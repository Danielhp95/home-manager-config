{ pkgs, ... }:

{
  services = {
    libinput.enable = true;
  };

  environment.etc."libinput-gestures.conf" = {
    text = ''
    gesture swipe up 4 kitty
    '';
    mode = "444";
  };

  # Not working!
  environment.systemPackages = with pkgs; [
    (libinput.overrideAttrs (oldAttrs: {
      nativeBuildInputs  = oldAttrs.nativeBuildInputs ++ [ wmctrl ];
      buildInputs  = oldAttrs.buildInputs ++ [ wmctrl ];
      propagatedBuildInputs  = oldAttrs.propagatedBuildInputs ++ [ wmctrl ];
    }))
    # still does not work!
    (libinput-gestures.overrideAttrs (oldAttrs: {
      nativeBuildInputs  = oldAttrs.nativeBuildInputs ++ [ wmctrl ];
      buildInputs  = oldAttrs.buildInputs ++ [ wmctrl ];
    }))
    wmctrl
    ydotool
    xdotool
  ];
}
