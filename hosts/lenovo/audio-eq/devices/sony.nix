# WH-1000XM6: AutoEq's 10-filter Harman correction (Kuulokenurkka). Assumes
# the Sony app's EQ is flat and DSEE/360 Upmix are off.
dsp:
with dsp;
sink {
  id = "sony_wh1000xm6";
  description = "WH-1000XM6 (EQ)";
  priority = priorities.headset;
  target = "bluez_output.80_99_E7_E7_B5_AA.1";
  nodes = [
    (peq "eq" [
      (preamp (-4.5))
      (lowshelf 105 (-4.0) 0.7)
      (peak 181 (-2.7) 0.79)
      (peak 1298 4.2 1.37)
      (peak 2112 (-2.9) 1.13)
      (peak 7457 5.2 1.98)
      (peak 53 0.6 1.86)
      (peak 93 (-0.2) 1.45)
      (peak 637 (-0.9) 3.67)
      (peak 840 0.9 4.2)
      (highshelf 10000 (-4.1) 0.7)
    ])
    (limiter { })
  ];
}
