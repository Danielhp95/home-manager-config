## Ollama
{
  pkgs,
  config,
  inputs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ opencode ];
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda;
    environmentVariables = {
      # Quantize the KV cache instead of the default f16 — it halves the cache
      # outright (measured: 4352 -> 2176 MiB at 32k), which is what pays for
      # the 64k window below. Needs flash attention to be on.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # Keep the whole 24GB budget for one model/request at a time instead of
      # splitting VRAM across concurrent loads or parallel request slots.
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      # Default window for any request that doesn't pass num_ctx. Ollama
      # auto-sizes this from VRAM and lands on 32k here, but 64k is free:
      # measured 119.5 vs 119.6 tok/s, 21385 MiB resident with ~3GB still
      # spare. 128k also fits and fully offloads, but costs ~27% of generation
      # speed (87 tok/s) — worth passing num_ctx explicitly for, not worth
      # making the default.
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
    loadModels = [
      # Qwen3-Coder-30B-A3B: 30.5B total parameters but a Mixture-of-Experts
      # with only ~3B active per token, so it costs 3B-class compute. On this
      # card (RTX 5090 Laptop, 24463 MiB) that is the difference between
      # fitting and not.
      #
      # Benchmarked against the dense Qwen3-32B UD-Q4_K_XL that used to be
      # here, same code-analysis prompt, same KV settings:
      #
      #                         prefill      generate    layers on GPU
      #   Qwen3-32B dense       848 tok/s    15.4 tok/s   63/65
      #   Qwen3-Coder-30B-A3B  2506 tok/s   119.6 tok/s   49/49
      #
      # The dense 32B was never fully resident — two layers ran on CPU and
      # every token crossed PCIe, which is where its 15 tok/s came from. A
      # dense 32B at Q4 does not fit 24GB alongside a real KV cache; shrinking
      # the window to 16k makes it fit but buys back only ~8%, because the
      # ceiling is the weights.
      #
      # Both models found 6/6 planted defects in a small bug-hunting test, so
      # the speed is not bought with quality. That test was three snippets —
      # enough to separate "finds real bugs" from "doesn't", not enough to
      # rank two models that both scored full marks.
      "qwen3-coder:30b"
    ];
  };

  services.open-webui = {
    enable = false;
    host = "0.0.0.0";
    # options: https://docs.openwebui.com/getting-started/advanced-topics/env-configuration
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
    };
  };
}
