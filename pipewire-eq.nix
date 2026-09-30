{
  pkgs,
  lib,
  ...
}:
# Per-device EQ as WirePlumber software-dsp chains ("(EQ)" sinks, "Laptop
# Microphone"), each present only while its device is. hide-parent hides the
# raw device from all clients but WirePlumber (its volume stays fixed; drop it
# to A/B). A switch doesn't reload curves: restart the user wireplumber.
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
  # is a stage of two nodes, one per channel (see `stage` in `chain`).
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

  # LSP's 16-band parametric EQ, same bands on both channels, the rest off.
  # Band keys omit the channel letter: ft 1 = bell, 2 = high-pass; s = slope
  # (0 = x1, 1 = x2); g is linear.
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

  # A software-dsp rule running `nodes` in order on device `target`; `capture`
  # props are for the side audio enters, `playback` for the side it leaves.
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

  # The stream to the device follows only it, so output can't blip onto
  # another sink while the chain unloads; linger keeps WirePlumber from
  # destroying that dont-fallback stream meanwhile (find-defined-target.lua).
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

  # Speakers above every hardware sink (the USB adapter's is 1109), headsets
  # above the speakers; they only decide when no sink you picked is present.
  speakerPriority = 1500;
  headsetPriority = 2500;

  # Lenovo's Dolby "Balanced" speaker tuning for this model, from the Windows
  # driver (n4fao15w.exe: SOUNDWIRE_MAN_01FA_FUNC_3556_SUBSYS_234717AA.xml) via
  # speaker-tuning-to-easyeffects 95ffa65; the FIR is in the .irs. If quiet
  # passages swell then duck, drop "autogain" (its compressor isn't rebuilt).
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

  # OpenRun Pro 2: AutoEq's RTINGS result, filters 1–6 at half gain (the ear
  # simulator mostly hears bone-conduction leakage; full gain buzzes). The
  # 40 Hz high-pass keeps the lifted bass from rattling.
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

  # WH-1000XM6: AutoEq's 10-filter Harman correction (Kuulokenurkka). Assumes
  # the Sony app's EQ is flat and DSEE/360 Upmix are off.
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

  # Laptop mic: RNNoise first (its model wants the raw signal), then EQ,
  # compressor, limiter. No gate: it clips word onsets, hurting dictation.
  # 2200 beats every other input (USB adapter 2109, headset 2010).
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
    # Stable's 0.5.14: 0.5.16+ destroys a chain's module twice on unload (every
    # headset disconnect), spinning WirePlumber at 100% CPU and hanging pactl
    # and wpctl. Unpin once a release fixes wp_impl_module_unload().
    package = pkgs.stable.wireplumber;
    extraLv2Packages = [
      pkgs.lsp-plugins
      pkgs.calf
    ];
    extraConfig."60-eq-sinks" = {
      # A filter-chain needs the adapter factory in WirePlumber's own context
      # ("no adapter factory found"). Request it as a profile component, not a
      # raw context.modules entry: loading client-node there too makes the
      # pw.client-node component fail with EEXIST, and monitor.bluez (which
      # requires it) is then skipped — no A2DP endpoints, no headsets.
      "wireplumber.profiles".main = {
        "node.software-dsp" = "required";
        "pw.node-factory.adapter" = "required";
      };
      "node.software-dsp.rules" = [
        speakers
        shokz
        sony
        thinkpadMic
      ];
    };
  };
}
