# Facts about this machine that more than one module needs, as plain data.
# Every module gets them as `host` (flake.nix), NixOS and Home Manager alike;
# hyprland.lua gets them as its `host` local (home/hyprland/default.nix).
{
  # The built-in panel: 3840x2400 at scale 2.
  panel = {
    output = "eDP-1";
    scale = 2;
    # What kanshi positions the other outputs against.
    logicalWidth = 1920;
    backlight = "intel_backlight";
  };

  # A preference more than a fact about the machine: it rides here until a
  # second machine makes the difference matter.
  keyboard = {
    layout = "us";
    options = "caps:escape";
  };
}
