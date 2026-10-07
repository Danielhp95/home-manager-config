# The constructors the device files in ./devices are written with: filter
# nodes, the chain that wires them, and the sink / source rules around it.
{ pkgs, lib }:
let
  # LSP's LV2 plugins by name.
  lsp = name: "http://lsp-plug.in/plugins/lv2/${name}";

  # { k = v; } per band -> { k_0 = …; k_1 = …; }, or kl_0 / kr_0 with
  # channels [ "l" "r" ]: how LSP's multi-band plugins name their controls.
  indexed =
    channels: bands:
    lib.listToAttrs (
      lib.concatLists (
        lib.imap0 (
          i: b:
          lib.concatMap (
            ch: lib.mapAttrsToList (k: v: lib.nameValuePair "${k}${ch}_${toString i}" v) b
          ) channels
        ) bands
      )
    );

  # A biquad band for `peq`, one line each: type, Hz, dB, Q.
  bq = type: freq: gain: q: {
    inherit
      type
      freq
      gain
      q
      ;
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
              if n.type == "builtin" then
                [
                  "In 1"
                  "In 2"
                ]
              else
                [
                  "in_l"
                  "in_r"
                ]
            );
            outs = map (p: "${n.name}:${p}") (
              if n.type == "builtin" then
                [
                  "Out 1"
                  "Out 2"
                ]
              else
                [
                  "out_l"
                  "out_r"
                ]
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
in
{
  inherit lsp indexed;

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

  # The bands `peq` takes, one line each: Hz, dB, Q.
  peak = bq "bq_peaking";
  lowshelf = bq "bq_lowshelf";
  highshelf = bq "bq_highshelf";
  highpass = freq: q: {
    type = "bq_highpass";
    inherit freq q;
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
      plugin = lsp "para_equalizer_x16_lr";
      control = {
        mode = 0;
        g_in = 1.0;
        g_out = gOut;
      }
      // indexed [ "l" "r" ] all;
    };

  # Bands for `lspPeq`: a bell at f Hz, linear gain g; a high-pass at slope x2.
  bell = f: g: q: {
    ft = 1;
    inherit f g q;
  };
  hp2 = f: {
    ft = 2;
    s = 1;
    inherit f;
  };

  # LSP/Calf controls are linear gains, not dB: 10^(dB/20).
  # `control` overrides the defaults below.
  limiter = control: {
    type = "lv2";
    name = "limiter";
    plugin = lsp "limiter_stereo";
    control = {
      g_in = 1.0;
      th = 0.8913; # -1 dBFS ceiling
      lk = 5.0;
      at = 5.0;
      rt = 20.0;
      alr = 0;
      boost = 0;
    }
    // control;
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

  # The rule for one device: its EQ'd sink (`eq_<id>`), or source (`<id>`).
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
  priorities = {
    speakers = 1500;
    headset = 2500;
  };
}
