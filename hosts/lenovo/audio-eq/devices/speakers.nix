# Lenovo's Dolby "Balanced" speaker tuning for this model, from the Windows
# driver (n4fao15w.exe: SOUNDWIRE_MAN_01FA_FUNC_3556_SUBSYS_234717AA.xml) via
# speaker-tuning-to-easyeffects 95ffa65; the FIR is in the .irs. If quiet
# passages swell then duck, drop "autogain" (its compressor isn't rebuilt).
dsp:
with dsp;
let
  # The multiband compressor's bands: split frequency (band 0 has none) and
  # ceiling (linear).
  split = sf: al: { inherit sf al; };
  bands = [
    { al = 0.1843422992; }
    (split 81.4 0.211348904)
    (split 181.6 0.4800096849)
    (split 277.0 0.5308844442)
    (split 392.2 0.5829415347)
    (split 554.7 0.427809082)
    (split 744.1 0.4308985176)
    (split 932.8 1.0)
  ];
  band =
    b:
    {
      ce = 1;
      inherit (b) al;
      at = 1.0;
      rrl = 9.988493699e-05;
      rt = 50.0;
      cr = 1.4545;
      kn = 0.5956621435;
      mk = 1.0;
      scm = 0;
      sla = 1.0;
      scp = 1.0;
      cm = 0;
      bth = 0.001;
      bsa = 1;
      sclc = 0;
      schc = 0;
      sclf = 10.0;
      schf = 20000.0;
    }
    // (
      if b ? sf then
        {
          cbe = 1;
          inherit (b) sf;
        }
      else
        { }
    );
in
sink {
  id = "laptop_speakers";
  description = "Laptop Speakers (EQ)";
  priority = priorities.speakers;
  target = "alsa_output.pci-0000_80_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
  nodes = [
    (convolver "conv" ../thinkpad_t16g_gen3_dolby_balanced.irs)
    {
      type = "lv2";
      name = "bass";
      plugin = "http://calf.sourceforge.net/plugins/BassEnhancer";
      control = {
        level_in = 1.0;
        level_out = 1.0;
        amount = 3.981071706; # +12 dB
        drive = 10.0;
        freq = 160.0;
        blend = -10.0;
        floor = 10.0;
        floor_active = 1;
        listen = 0;
      };
    }
    (lspPeq {
      name = "peq";
      gOut = 0.7943282347; # -2 dB
      bands = [
        (hp2 80)
        (hp2 80)
        (hp2 80)
        (bell 120 1.258925412 0.7) # +2 dB
      ];
    })
    (lspPeq {
      name = "dialog";
      bands = [ (bell 2500 1.241652308 0.7) ]; # +1.9 dB
    })
    {
      type = "lv2";
      name = "autogain";
      plugin = lsp "autogain_stereo";
      control = {
        level = -26.0;
        silence = -50.0;
        weight = 5.0;
        lkahead = 0.0;
        tgrow_l = 10000.0;
        tfall_l = 4000.0;
      };
    }
    {
      type = "lv2";
      name = "reg";
      plugin = lsp "mb_compressor_stereo";
      control = {
        mode = 1;
        g_in = 1.995262315; # +6 dB (volmax boost)
        g_out = 1.0;
        g_dry = 9.988493699e-05;
        g_wet = 1.0;
        envb = 0;
      }
      // indexed [ "" ] (map band bands);
    }
    (limiter {
      mode = 0;
      g_out = 1.0;
      th = 0.8912509381; # -1 dBFS
      lk = 1.0;
      at = 1.0;
      rt = 5.0;
      slink = 100.0;
    })
  ];
}
