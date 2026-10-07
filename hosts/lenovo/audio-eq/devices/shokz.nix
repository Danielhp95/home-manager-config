# OpenRun Pro 2: AutoEq's RTINGS result, filters 1–6 at half gain (the ear
# simulator mostly hears bone-conduction leakage; full gain buzzes). The
# 40 Hz high-pass keeps the lifted bass from rattling.
dsp:
with dsp;
sink {
  id = "shokz_openrun";
  description = "Shokz OpenRun (EQ)";
  priority = priorities.headset;
  target = "bluez_output.A8_F5_E1_94_F8_E7.1";
  nodes = [
    (peq "eq" [
      (preamp (-5.0))
      (highpass 40 0.707)
      (lowshelf 105 3.0 0.7)
      (peak 139 2.9 1.09)
      (peak 1692 (-5.75) 0.21)
      (peak 3671 4.4 1.84)
      (peak 6694 5.8 0.5)
      (highshelf 10000 2.0 0.7)
    ])
    (limiter { })
  ];
}
