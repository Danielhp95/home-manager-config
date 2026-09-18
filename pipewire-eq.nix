{ pkgs, lib, ... }:
# Per-device EQ as PipeWire filter-chain sinks: "Laptop Speakers (EQ)",
# "Shokz OpenRun (EQ)", "WH-1000XM6 (EQ)". Each is an ordinary Audio/Sink
# that plays into its hardware device, so any app can be moved to any of them
# from pavucontrol / Noctalia / the app itself, and several can run at once.
# (EasyEffects only ever processes one output, which is why outputs moved
# here; it keeps the mic, see easyeffects.nix.)
#
# They run in their own `pipewire -c` client rather than as a pipewire.conf.d
# drop-in, so changing a curve restarts this unit only, not the audio daemon.
#
# Pick the "(EQ)" entry to hear the correction; the raw device next to it is
# still there for A/B. A sink whose headphones are disconnected stays listed
# but silent, rather than falling back to the speakers, and reattaches when
# they reconnect.
let
  lv2Path = lib.makeSearchPath "lib/lv2" [
    pkgs.lsp-plugins
    pkgs.calf
  ];

  # Same filter list on both channels (param_eq "In 1"/"In 2").
  peq = name: filters: {
    type = "builtin";
    inherit name;
    label = "param_eq";
    config = {
      filters1 = filters;
      filters2 = filters;
    };
  };

  preamp = gain: {
    type = "bq_highshelf";
    freq = 0;
    inherit gain;
  };

  # LSP/Calf controls are linear gains, not dB: 10^(dB/20).
  limiter =
    {
      inputGain ? 1.0,
    }:
    {
      type = "lv2";
      name = "limiter";
      plugin = "http://lsp-plug.in/plugins/lv2/limiter_stereo";
      control = {
        g_in = inputGain;
        th = 0.8913; # -1 dBFS ceiling
        lk = 5.0;
        at = 5.0;
        rt = 20.0;
        alr = 0;
        boost = 0;
      };
    };

  sink =
    {
      id,
      description,
      target,
      nodes,
    }:
    let
      first = builtins.head nodes;
      last = lib.last nodes;
      portsIn = n: if n.type == "builtin" then [ "In 1" "In 2" ] else [ "in_l" "in_r" ];
      portsOut = n: if n.type == "builtin" then [ "Out 1" "Out 2" ] else [ "out_l" "out_r" ];
      pairs = lib.zipLists (lib.init nodes) (lib.tail nodes);
    in
    {
      name = "libpipewire-module-filter-chain";
      args = {
        "node.description" = description;
        "media.name" = description;
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
        "filter.graph" = {
          nodes = nodes;
          links = lib.concatMap (
            p:
            lib.zipListsWith (o: i: {
              output = "${p.fst.name}:${o}";
              input = "${p.snd.name}:${i}";
            }) (portsOut p.fst) (portsIn p.snd)
          ) pairs;
          inputs = map (p: "${first.name}:${p}") (portsIn first);
          outputs = map (p: "${last.name}:${p}") (portsOut last);
        };
        "capture.props" = {
          "node.name" = "eq_${id}";
          "media.class" = "Audio/Sink";
        };
        "playback.props" = {
          "node.name" = "eq_${id}_out";
          "target.object" = target;
          "node.passive" = true;
          # Wait for the device instead of falling back to the default sink
          # (Shokz EQ must never play through the speakers). Without linger,
          # WirePlumber destroys a dont-fallback stream whose target is absent
          # (find-defined-target.lua), and it would never come back.
          "node.dont-fallback" = true;
          "node.linger" = true;
        };
      };
    };

  # OMEN MAX 16 (16-ah000) speakers, fitted to Notebookcheck's pink-noise
  # measurement of this model (relative to its 64.1 dB median):
  #   100 Hz -29 | 160 -7.6 | 200 -4.1 | 250–630 ±1.3 | 800 +3.0
  #   1 kHz +4.9 | 2 kHz +3.7 | 4 kHz +3.9 | 8 kHz -2.9 | 10–16 kHz -3.6
  # Nothing below ~150 Hz is boosted (the drivers can't play it, boosting
  # only distorts): high-pass there and let Calf's bass enhancer imply it with
  # harmonics. Narrow cuts flatten the 1/2/4 kHz peaks, a shelf restores the
  # top octave; simulated result stays within ±1.3 dB from 200 Hz to 16 kHz.
  # The limiter turns the -3.5 dB preamp back into loudness (78 dB(A) max).
  # Caveat: measured under Windows with HP's driver tuning; Linux has none.
  laptopSpeakers = sink {
    id = "laptop_speakers";
    description = "Laptop Speakers (EQ)";
    target = "alsa_output.pci-0000_80_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";
    nodes = [
      (peq "eq" [
        (preamp (-3.5))
        {
          type = "bq_highpass";
          freq = 110;
          q = 0.707;
        }
        {
          type = "bq_highpass";
          freq = 110;
          q = 0.707;
        }
        {
          type = "bq_peaking";
          freq = 180;
          gain = 3.0;
          q = 1.4;
        }
        {
          type = "bq_peaking";
          freq = 1000;
          gain = -3.5;
          q = 1.8;
        }
        {
          type = "bq_peaking";
          freq = 2000;
          gain = -2.5;
          q = 3.0;
        }
        {
          type = "bq_peaking";
          freq = 4000;
          gain = -3.0;
          q = 2.5;
        }
        {
          type = "bq_highshelf";
          freq = 7000;
          gain = 3.5;
          q = 0.707;
        }
      ])
      {
        type = "lv2";
        name = "bass";
        plugin = "http://calf.sourceforge.net/plugins/BassEnhancer";
        control = {
          amount = 1.5849; # +4 dB
          drive = 8.5;
          blend = 0.0;
          freq = 180.0;
          floor_active = 1;
          floor = 40.0;
        };
      }
      (limiter { inputGain = 1.7783; }) # +5 dB
    ];
  };

  # OpenRun Pro 2: AutoEq's RTINGS (B&K 5128) result, filters 1–6 at half
  # gain. Half, because an ear simulator mostly hears a bone-conduction
  # headset's air leakage — the raw ±11 dB correction is harsh and buzzes
  # through the transducers. The 40 Hz high-pass keeps the lifted bass from
  # rattling; the limiter is only a safety.
  shokz = sink {
    id = "shokz_openrun";
    description = "Shokz OpenRun (EQ)";
    target = "bluez_output.A8_F5_E1_94_F8_E7.1";
    nodes = [
      (peq "eq" [
        (preamp (-5.0))
        {
          type = "bq_highpass";
          freq = 40;
          q = 0.707;
        }
        {
          type = "bq_lowshelf";
          freq = 105;
          gain = 3.0;
          q = 0.7;
        }
        {
          type = "bq_peaking";
          freq = 139;
          gain = 2.9;
          q = 1.09;
        }
        {
          type = "bq_peaking";
          freq = 1692;
          gain = -5.75;
          q = 0.21;
        }
        {
          type = "bq_peaking";
          freq = 3671;
          gain = 4.4;
          q = 1.84;
        }
        {
          type = "bq_peaking";
          freq = 6694;
          gain = 5.8;
          q = 0.5;
        }
        {
          type = "bq_highshelf";
          freq = 10000;
          gain = 2.0;
          q = 0.7;
        }
      ])
      (limiter { })
    ];
  };

  # WH-1000XM6: AutoEq's full 10-filter correction to the Harman target
  # (Kuulokenurkka measurement). Assumes the Sony app's EQ is flat and
  # DSEE/360 Upmix are off, otherwise the headphone's own DSP stacks on top.
  sony = sink {
    id = "sony_wh1000xm6";
    description = "WH-1000XM6 (EQ)";
    target = "bluez_output.80_99_E7_E7_B5_AA.1";
    nodes = [
      (peq "eq" [
        (preamp (-4.5))
        {
          type = "bq_lowshelf";
          freq = 105;
          gain = -4.0;
          q = 0.7;
        }
        {
          type = "bq_peaking";
          freq = 181;
          gain = -2.7;
          q = 0.79;
        }
        {
          type = "bq_peaking";
          freq = 1298;
          gain = 4.2;
          q = 1.37;
        }
        {
          type = "bq_peaking";
          freq = 2112;
          gain = -2.9;
          q = 1.13;
        }
        {
          type = "bq_peaking";
          freq = 7457;
          gain = 5.2;
          q = 1.98;
        }
        {
          type = "bq_peaking";
          freq = 53;
          gain = 0.6;
          q = 1.86;
        }
        {
          type = "bq_peaking";
          freq = 93;
          gain = -0.2;
          q = 1.45;
        }
        {
          type = "bq_peaking";
          freq = 637;
          gain = -0.9;
          q = 3.67;
        }
        {
          type = "bq_peaking";
          freq = 840;
          gain = 0.9;
          q = 4.2;
        }
        {
          type = "bq_highshelf";
          freq = 10000;
          gain = -4.1;
          q = 0.7;
        }
      ])
      (limiter { })
    ];
  };

  # A standalone client config: pipewire.conf syntax accepts plain JSON.
  conf = pkgs.writeText "pipewire-eq-sinks.conf" (
    builtins.toJSON {
      "context.properties" = {
        "log.level" = 2;
      };
      "context.spa-libs" = {
        "audio.convert.*" = "audioconvert/libspa-audioconvert";
        "support.*" = "support/libspa-support";
      };
      "context.modules" = [
        {
          name = "libpipewire-module-rt";
          flags = [
            "ifexists"
            "nofail"
          ];
        }
        { name = "libpipewire-module-protocol-native"; }
        { name = "libpipewire-module-client-node"; }
        { name = "libpipewire-module-adapter"; }
        laptopSpeakers
        shokz
        sony
      ];
    }
  );
in
{
  systemd.user.services.pipewire-eq-sinks = {
    Unit = {
      Description = "Per-device EQ sinks (PipeWire filter-chain)";
      After = [ "pipewire.service" ];
      BindsTo = [ "pipewire.service" ];
      X-Restart-Triggers = [ "${conf}" ];
    };
    Service = {
      ExecStart = "${pkgs.pipewire}/bin/pipewire -c ${conf}";
      Environment = [ "LV2_PATH=${lv2Path}" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    # default.target, not pipewire.service: a switch only starts units the
    # session target wants, so WantedBy=pipewire.service was installed but
    # never started (BindsTo still pulls pipewire in and stops with it).
    Install.WantedBy = [ "default.target" ];
  };
}
