{ ... }:
{
  # Display layout profiles. kanshi watches outputs come and go over
  # wlr-output-management and applies the first profile below whose outputs
  # match exactly what is connected, so plugging a screen in is enough.
  #
  # Hyprland keeps what kanshi sets as a per-output override on top of its own
  # monitor rules (OutputManagement's m_monitorStates, never cleared), so a
  # Hyprland reload does not undo the layout. hyprland.lua keeps the ""
  # wildcard rule, which covers the moment before kanshi applies and any setup
  # no profile matches (e.g. two unknown screens at once), plus an eDP-1 rule
  # for the panel's scale (2, so 1920 logical wide, as the positions below
  # assume) and ICC profile. The override only patches mode/position/scale,
  # so the profile survives it.
  #
  # Order matters: profiles are tried top to bottom, and `desk` also satisfies
  # `any-external` (whose "*" matches the Dell too).
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
        # Laptop plus any other screen: that screen goes to the right of the
        # laptop, top edges aligned.
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
