{ host, ... }:
let
  panel = host.panel.output;
in
{
  # Display layouts: kanshi applies the first profile whose outputs match what
  # is connected, and Hyprland keeps it across reloads. Positions assume the
  # built-in panel at its scale and logical width (hosts/<host>/facts.nix).
  #
  # Order matters: `desk` also satisfies `any-external` ("*" matches the Dell).
  services.kanshi = {
    enable = true;
    settings = [
      {
        # Dell directly above the laptop, edges aligned (both 1920 wide).
        profile.name = "desk";
        profile.outputs = [
          {
            criteria = "Dell Inc. DELL P2422H FYZW7W3";
            position = "0,0";
          }
          {
            criteria = panel;
            position = "0,1080";
          }
        ];
      }
      {
        # Any other screen goes right of the laptop, top edges aligned.
        profile.name = "any-external";
        profile.outputs = [
          {
            criteria = panel;
            position = "0,0";
          }
          {
            criteria = "*";
            position = "${toString host.panel.logicalWidth},0";
          }
        ];
      }
      {
        profile.name = "laptop";
        profile.outputs = [
          {
            criteria = panel;
            position = "0,0";
          }
        ];
      }
    ];
  };
}
