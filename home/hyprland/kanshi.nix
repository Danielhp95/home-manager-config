_: {
  # Display layouts: kanshi applies the first profile whose outputs match what
  # is connected, and Hyprland keeps it across reloads. Positions assume eDP-1
  # at scale 2 (1920 logical wide, hyprland.lua).
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
            criteria = "eDP-1";
            position = "0,1080";
          }
        ];
      }
      {
        # Any other screen goes right of the laptop, top edges aligned.
        profile.name = "any-external";
        profile.outputs = [
          {
            criteria = "eDP-1";
            position = "0,0";
          }
          {
            criteria = "*";
            position = "1920,0";
          }
        ];
      }
      {
        profile.name = "laptop";
        profile.outputs = [
          {
            criteria = "eDP-1";
            position = "0,0";
          }
        ];
      }
    ];
  };
}
