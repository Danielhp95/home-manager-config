{
  inputs,
  pkgs,
  lib,
  ...
}:
# Per-device EQ as PipeWire filter-chain sinks: "Laptop Speakers (EQ)",
# "Shokz OpenRun (EQ)", "WH-1000XM6 (EQ)". Each is an ordinary Audio/Sink
# that plays into its hardware device, so any app can be moved to any of them
# from pavucontrol / Noctalia / the app itself, and several can run at once.
# The laptop mic gets the same treatment in the other direction: "Laptop
# Microphone" is an Audio/Source that records through its chain. (This used
# to be EasyEffects, which only processes one output and adds its own sink
# and source to every device list.)
#
# Each chain exists only while its device does: WirePlumber's software-dsp
# hook loads the filter-chain when the device's node appears and unloads it
# when the node goes, so a headset's "(EQ)" entry is hidden until it connects.
#
# The chain also hides its device (hide-parent): every client but WirePlumber
# loses sight of the raw node, so apps (Slack's pickers, pavucontrol,
# Noctalia, wpctl) list only the processed entry, and PulseAudio apps lose the
# raw sink's "Monitor of" source too. The raw volume is then out of reach, so
# it stays where it was when the chain loaded; volume is the chain's own. For
# A/B, drop hide-parent and restart WirePlumber.
#
# The chains carry priority.session above any hardware node, so WirePlumber
# never falls back to a hidden device as the default.
#
# When a headset drops, its EQ sink goes with it. WirePlumber pauses MPRIS
# players that were feeding it (linking.pause-playback, on by default) before
# relinking their streams; anything else falls back to the default sink, as
# with the raw device. If the EQ sink was the default, it becomes the default
# again when the headset reconnects.
#
# The chains run inside WirePlumber, so a curve change needs
# `systemctl --user restart wireplumber` after the switch (a switch does not
# restart it), which briefly drops Bluetooth audio.
let
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

  # Stereo FIR from a 2-channel .irs. The builtin convolver is mono, so this
  # is a stage of two nodes, one per channel (see `stage` in `sink`).
  convolver =
    name: file:
    let
      side = ch: channel: {
        type = "builtin";
        name = "${name}_${ch}";
        label = "convolver";
        config = {
          filename = "${file}";
          inherit channel;
          gain = 1.0;
        };
      };
    in
    {
      nodes = [
        (side "l" 0)
        (side "r" 1)
      ];
      ins = [
        "${name}_l:In"
        "${name}_r:In"
      ];
      outs = [
        "${name}_l:Out"
        "${name}_r:Out"
      ];
    };

  # LSP's 16-band parametric EQ with the same bands on both channels; bands
  # past the list are off. Band keys drop the channel letter (ft, f, g, q, s,
  # ...): ft 1 = bell, 2 = high-pass; s is the slope (0 = x1, 1 = x2); g is
  # linear.
  lspPeq =
    {
      name,
      bands,
      gOut ? 1.0,
    }:
    let
      band =
        b:
        {
          fm = 0;
          s = 0;
          g = 1.0;
          q = 0.707;
          w = 4;
          xm = 0;
          xs = 0;
        }
        // b;
      all = map band bands ++ lib.genList (_: { ft = 0; }) (16 - builtins.length bands);
    in
    {
      type = "lv2";
      inherit name;
      plugin = "http://lsp-plug.in/plugins/lv2/para_equalizer_x16_lr";
      control = {
        mode = 0;
        g_in = 1.0;
        g_out = gOut;
      }
      // lib.listToAttrs (
        lib.concatLists (
          lib.imap0 (
            i: b:
            lib.concatMap (
              ch: lib.mapAttrsToList (k: v: lib.nameValuePair "${k}${ch}_${toString i}" v) b
            ) [ "l" "r" ]
          ) all
        )
      );
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

  # RNNoise (noise-suppression-for-voice), a ready stage like `convolver`:
  # its LADSPA ports have names of their own.
  rnnoise = name: {
    nodes = [
      {
        type = "ladspa";
        inherit name;
        plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
        label = "noise_suppressor_stereo";
        # 0 disables the voice-activity gate: denoise only, never mute.
        control."VAD Threshold (%)" = 0.0;
      }
    ];
    ins = [
      "${name}:Input (L)"
      "${name}:Input (R)"
    ];
    outs = [
      "${name}:Output (L)"
      "${name}:Output (R)"
    ];
  };

  # A software-dsp rule running `nodes` in order on the device `target`, with
  # the chain's two streams' props: `capture` is the side audio enters,
  # `playback` the side it leaves.
  chain =
    {
      target,
      description,
      nodes,
      capture,
      playback,
    }:
    let
      # A plain node is a stage of its own; `convolver` returns a ready stage.
      stage =
        n:
        if n ? ins then
          n
        else
          {
            nodes = [ n ];
            ins = map (p: "${n.name}:${p}") (
              if n.type == "builtin" then [ "In 1" "In 2" ] else [ "in_l" "in_r" ]
            );
            outs = map (p: "${n.name}:${p}") (
              if n.type == "builtin" then [ "Out 1" "Out 2" ] else [ "out_l" "out_r" ]
            );
          };
      stages = map stage nodes;
      pairs = lib.zipLists (lib.init stages) (lib.tail stages);
    in
    {
      matches = [ { "node.name" = target; } ];
      actions.create-filter = {
        hide-parent = true;
        # The filter-chain module's args.
        filter-graph = {
          "node.description" = description;
          "media.name" = description;
          "audio.channels" = 2;
          "audio.position" = [
            "FL"
            "FR"
          ];
          "filter.graph" = {
            nodes = lib.concatMap (s: s.nodes) stages;
            links = lib.concatMap (
              p: lib.zipListsWith (output: input: { inherit output input; }) p.fst.outs p.snd.ins
            ) pairs;
            inputs = (builtins.head stages).ins;
            outputs = (lib.last stages).outs;
          };
          "capture.props" = capture;
          "playback.props" = playback;
        };
      };
    };

  # The stream that talks to the device. It follows only its device: covers
  # the moment between the device going away and WirePlumber unloading this
  # chain, so a sink's output can't blip onto the default sink (the
  # speakers), nor a source record another mic. Without linger, WirePlumber
  # destroys a dont-fallback stream whose target is absent
  # (find-defined-target.lua).
  deviceStream = target: {
    "target.object" = target;
    "node.passive" = true;
    "node.dont-fallback" = true;
    "node.linger" = true;
  };

  sink =
    {
      id,
      description,
      target,
      nodes,
      priority,
    }:
    chain {
      inherit target description nodes;
      capture = {
        "node.name" = "eq_${id}";
        "media.class" = "Audio/Sink";
        "priority.session" = priority;
      };
      playback = deviceStream target // {
        "node.name" = "eq_${id}_out";
      };
    };

  source =
    {
      id,
      description,
      target,
      nodes,
      priority,
    }:
    chain {
      inherit target description nodes;
      capture = deviceStream target // {
        "node.name" = "${id}_in";
      };
      playback = {
        "node.name" = id;
        "media.class" = "Audio/Source";
        "priority.session" = priority;
      };
    };

  # Output priorities: the laptop's chain above every visible hardware sink
  # (the USB adapter's is 1109), a headset's above the laptop's. They only
  # decide when no sink you picked is present; then a connected headset wins.
  speakerPriority = 1500;
  headsetPriority = 2500;

  # ThinkPad T16g Gen 3 (21V6, subsystem 17aa:2347; CS35L56 amps on
  # SoundWire): Lenovo's own Dolby Atmos (DAX3) speaker tuning, the processing
  # Windows runs on top of the Cirrus amp tuning, which Linux already loads
  # (cirrus/cs35l56-b0-dsp1-misc-17aa2347*). Source: the Windows audio driver
  # (AUD_N4FAO 1.0.569.57807, download.lenovo.com/pccbbs/mobiles/n4fao15w.exe),
  # file Dolby/dax3/ext_thinkpad_AIO_cirrus_*/SOUNDWIRE_MAN_01FA_FUNC_3556_SUBSYS_234717AA.xml,
  # converted by speaker-tuning-to-easyeffects (commit 95ffa65) with its
  # defaults: `dolby_to_pipewire.py <xml>`, Dolby's "Balanced" voicing. The FIR
  # (the per-device speaker correction) is in the .irs; the rest is:
  #   bass enhancer (+12 dB harmonics from 160 Hz) -> 80 Hz high-pass
  #   (3 stacked, x2 slope) + 120 Hz +2 dB -> dialog lift 2.5 kHz +1.9 dB ->
  #   Dolby's volume leveler (-26 LUFS) -> 8-band regulator (+6 dB volmax
  #   boost, per-band ceilings) -> -1 dBFS limiter.
  # If quiet passages swell and then duck, drop "autogain": the converter
  # can't rebuild the leveler's companion compressor (its [leveler-gap]).
  speakers = sink {
    id = "laptop_speakers";
    description = "Laptop Speakers (EQ)";
    priority = speakerPriority;
    target = "alsa_output.pci-0000_80_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
    nodes = [
      (convolver "conv" ./pipewire-eq/thinkpad_t16g_gen3_dolby_balanced.irs)
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
        bands =
          lib.replicate 3 {
            ft = 2;
            s = 1;
            f = 80;
          }
          ++ [
            {
              ft = 1;
              f = 120;
              g = 1.258925412; # +2 dB
              q = 0.7;
            }
          ];
      })
      (lspPeq {
        name = "dialog";
        bands = [
          {
            ft = 1;
            f = 2500;
            g = 1.241652308; # +1.9 dB
            q = 0.7;
          }
        ];
      })
      {
        type = "lv2";
        name = "autogain";
        plugin = "http://lsp-plug.in/plugins/lv2/autogain_stereo";
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
        plugin = "http://lsp-plug.in/plugins/lv2/mb_compressor_stereo";
        control =
          let
            # Band i's split frequency (band 0 has none) and ceiling (linear).
            bands = [
              { al = 0.1843422992; }
              {
                sf = 81.4;
                al = 0.211348904;
              }
              {
                sf = 181.6;
                al = 0.4800096849;
              }
              {
                sf = 277.0;
                al = 0.5308844442;
              }
              {
                sf = 392.2;
                al = 0.5829415347;
              }
              {
                sf = 554.7;
                al = 0.427809082;
              }
              {
                sf = 744.1;
                al = 0.4308985176;
              }
              {
                sf = 932.8;
                al = 1.0;
              }
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
              // lib.optionalAttrs (b ? sf) {
                cbe = 1;
                inherit (b) sf;
              };
          in
          {
            mode = 1;
            g_in = 1.995262315; # +6 dB (volmax boost)
            g_out = 1.0;
            g_dry = 9.988493699e-05;
            g_wet = 1.0;
            envb = 0;
          }
          // lib.listToAttrs (
            lib.concatLists (
              lib.imap0 (
                i: b: lib.mapAttrsToList (k: v: lib.nameValuePair "${k}_${toString i}" v) (band b)
              ) bands
            )
          );
      }
      {
        type = "lv2";
        name = "limiter";
        plugin = "http://lsp-plug.in/plugins/lv2/limiter_stereo";
        control = {
          mode = 0;
          g_in = 1.0;
          g_out = 1.0;
          th = 0.8912509381; # -1 dBFS
          lk = 1.0;
          at = 1.0;
          rt = 5.0;
          slink = 100.0;
          alr = 0;
          boost = 0;
        };
      }
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
    priority = headsetPriority;
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
    priority = headsetPriority;
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

  # ThinkPad T16g Gen 3 digital mic, for calls and voxtype dictation. RNNoise
  # first (its model expects the raw signal), then a high-pass for desk rumble
  # and fan hum, less mud, a presence lift for intelligibility, a gentle
  # compressor to even out distance from the mic, and a safety limiter. No
  # gate: it clips the starts of words, which hurts transcription. Its
  # priority beats every other input (the USB adapter's mic is 2109, the
  # headset's 2010), so it stays the default mic.
  thinkpadMic = source {
    id = "laptop_mic";
    description = "Laptop Microphone";
    target = "alsa_input.pci-0000_80_1f.3-platform-sof_sdw.HiFi__Mic__source";
    priority = 2200;
    nodes = [
      (rnnoise "rnnoise")
      (lspPeq {
        name = "eq";
        bands = [
          {
            ft = 2;
            s = 1;
            f = 80;
          }
          {
            ft = 1;
            f = 250;
            g = 0.7943282347; # -2 dB
            q = 1.0;
          }
          {
            ft = 1;
            f = 4000;
            g = 1.258925412; # +2 dB
            q = 1.0;
          }
        ];
      })
      {
        type = "lv2";
        name = "comp";
        plugin = "http://lsp-plug.in/plugins/lv2/compressor_stereo";
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
  };
in
{
  services.pipewire.wireplumber = {
    # Pinned to stable (0.5.14). Since 0.5.16, WirePlumber hosts in-process
    # modules on a separate client-context thread but unloads them from its
    # main thread; a chain's filter-chain module schedules its own destroy
    # mid-teardown, gets destroyed twice, and the main thread spins at 100% CPU,
    # wedging every graph client (pactl, pavucontrol, wpctl) until WirePlumber
    # is restarted. Every chain unload hit it, i.e. every headset disconnect.
    # 0.5.14 has no client context. Unpin once a release after 0.5.17 fixes
    # wp_impl_module_unload().
    package = inputs.stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.wireplumber;
    extraLv2Packages = [
      pkgs.lsp-plugins
      pkgs.calf
    ];
    extraConfig."60-eq-sinks" = {
      "wireplumber.profiles".main."node.software-dsp" = "required";
      # WirePlumber's own context loads neither, and a filter-chain cannot
      # create its streams without them ("no adapter factory found").
      "context.modules" = [
        { name = "libpipewire-module-client-node"; }
        { name = "libpipewire-module-adapter"; }
      ];
      "node.software-dsp.rules" = [
        speakers
        shokz
        sony
        thinkpadMic
      ];
    };
  };
}
