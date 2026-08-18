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
    enable = true;
    host = "0.0.0.0";
    # options: https://docs.openwebui.com/getting-started/advanced-topics/env-configuration
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
      # Qwen3's chat template already supports tool calling; this just wires
      # up a "web search" tool the model can invoke, backed by the local
      # SearXNG instance below (loopback-only, never leaves the box).
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:${toString config.services.searx.settings.server.port}/search?q=<query>";
      RAG_WEB_SEARCH_RESULT_COUNT = "5";
      RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
    };
  };

  # Local meta-search backend for open-webui's web-search tool. Loopback-only
  # (no openFirewall, no nginx) since only open-webui on the same host talks
  # to it.
  services.searx = {
    enable = true;
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        # Not sensitive: only signs CSRF-style tokens for a service that
        # never leaves loopback and has no accounts of its own.
        secret_key = "f02884e092fa373713e6278b768dda51f40715527abb7d1274f0b603fbae5b37";
      };
      # json is required for open-webui to consume results via the API;
      # html is kept so `searx` is still browsable directly for debugging.
      search.formats = [
        "html"
        "json"
      ];
    };
  };
}
