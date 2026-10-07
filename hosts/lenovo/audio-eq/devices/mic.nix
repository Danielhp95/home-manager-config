# Laptop mic: RNNoise first (its model wants the raw signal), then EQ,
# compressor, limiter. No gate: it clips word onsets, hurting dictation.
# 2200 beats every other input (USB adapter 2109, headset 2010).
dsp:
with dsp;
source {
  id = "laptop_mic";
  description = "Laptop Microphone";
  target = "alsa_input.pci-0000_80_1f.3-platform-sof_sdw.HiFi__Mic__source";
  priority = 2200;
  nodes = [
    (rnnoise "rnnoise")
    (lspPeq {
      name = "eq";
      bands = [
        (hp2 80)
        (bell 250 0.7943282347 1.0) # -2 dB
        (bell 4000 1.258925412 1.0) # +2 dB
      ];
    })
    {
      type = "lv2";
      name = "comp";
      plugin = lsp "compressor_stereo";
      control = {
        cm = 0; # downward
        al = 0.06309573445; # -24 dB threshold
        cr = 3.0;
        at = 10.0;
        rt = 150.0;
        kn = 0.5011872336; # -6 dB
        mk = 1.778279410; # +5 dB makeup
      };
    }
    (limiter { })
  ];
}
