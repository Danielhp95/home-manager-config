{ lib, ... }:
# EasyEffects: microphone processing only.
#
# Outputs are not EasyEffects' job here: it runs a single output pipeline to a
# single device, and it pulls every app's stream onto its own sink, which
# breaks picking a per-app output in pavucontrol. Per-device output EQ lives in
# pipewire-eq.nix as ordinary filter-chain sinks instead, so
# processAllOutputs is off and no output preset exists.
#
# The mic preset is loaded by an autoload profile, named
# `<node.name>:<route description>.json` (both from `pw-dump`: the node's name
# and the Route param of its device); any other input gets the empty `flat`.
#
# Preset JSON is EasyEffects 8.2's format (keys from src/*_preset.cpp, enum
# strings from src/contents/kcfg). Keys left out take the plugin default, but
# an equalizer must list every band it declares in both `left` and `right`.
let
  # An equalizer instance from a list of bands, mirrored to both channels.
  eq =
    {
      inputGain ? 0.0,
      bands,
    }:
    let
      channel = lib.listToAttrs (
        lib.imap0 (
          i: b:
          lib.nameValuePair "band${toString i}" (
            {
              mode = "RLC (BT)";
              slope = "x1";
              q = 0.7;
              gain = 0.0;
              mute = false;
              solo = false;
            }
            // b
          )
        ) bands
      );
    in
    {
      bypass = false;
      mode = "IIR";
      "input-gain" = inputGain;
      "output-gain" = 0.0;
      "num-bands" = builtins.length bands;
      "split-channels" = false;
      left = channel;
      right = channel;
    };

  autoload = pipeline: device: route: preset: {
    "easyeffects/autoload/${pipeline}/${device}:${route}.json".text = builtins.toJSON {
      inherit device;
      "device-description" = device;
      "device-profile" = route;
      "preset-name" = preset;
    };
  };

  laptopMic = "alsa_input.pci-0000_80_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source";
in
{
  services.easyeffects = {
    enable = true;

    settings = {
      # Leave app output streams where the user put them.
      EffectsPipelines.processAllOutputs = false;
      Window = {
        outputAutoloadingUsesFallback = false;
        inputAutoloadingUsesFallback = true;
        inputAutoloadingFallbackPreset = "flat";
      };
    };

    extraPresets = {
      flat.input = {
        blocklist = [ ];
        plugins_order = [ ];
      };

      # Laptop digital mic, for calls and voxtype dictation. RNNoise first
      # (its model expects the raw signal), then a high-pass for desk rumble
      # and fan hum, less mud, a presence lift for intelligibility, a gentle
      # compressor to even out distance from the mic, and a safety limiter.
      # No gate: it clips the starts of words, which hurts transcription.
      laptop-mic.input = {
        blocklist = [ ];
        plugins_order = [
          "rnnoise#0"
          "equalizer#0"
          "compressor#0"
          "limiter#0"
        ];
        "rnnoise#0" = {
          bypass = false;
          "use-standard-model" = true;
          "enable-vad" = false;
          wet = 0.0;
          release = 20.0;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
        };
        "equalizer#0" = eq {
          bands = [
            {
              type = "Hi-pass";
              frequency = 80.0;
              slope = "x2";
            }
            {
              type = "Bell";
              frequency = 250.0;
              gain = -2.0;
              q = 1.0;
            }
            {
              type = "Bell";
              frequency = 4000.0;
              gain = 2.0;
              q = 1.0;
            }
          ];
        };
        "compressor#0" = {
          bypass = false;
          mode = "Downward";
          threshold = -24.0;
          ratio = 3.0;
          attack = 10.0;
          release = 150.0;
          knee = -6.0;
          makeup = 5.0;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
        };
        "limiter#0" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
          threshold = -1.0;
          lookahead = 5.0;
          attack = 5.0;
          release = 20.0;
        };
      };
    };
  };

  xdg.dataFile = autoload "input" laptopMic "Digital Microphone" "laptop-mic";
}
