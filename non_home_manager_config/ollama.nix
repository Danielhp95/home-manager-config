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
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_LOAD_TIMEOUT = "15m";
      # Default window for any request that doesn't pass num_ctx. Ollama
      # auto-sizes this from VRAM and lands on 32k here, but 64k is free:
      # measured 119.5 vs 119.6 tok/s, 21385 MiB resident with ~3GB still
      # spare. 128k also fits and fully offloads, but costs ~27% of generation
      # speed (87 tok/s) — worth passing num_ctx explicitly for, not worth
      # making the default.
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
    loadModels = [
      "qwen3-coder:30b"  # Local development
      "qwen3:4b-instruct-2507-q4_K_M"  # IRIS
    ];
  };

  # iris-qwen3-4b: the model above with num_ctx baked in, which is what IRIS
  # actually requests. ollama's OpenAI-compatible endpoint, the only API IRIS
  # speaks, ignores `options.num_ctx` in the request body. So the plain tag
  # always loads at OLLAMA_CONTEXT_LENGTH x OLLAMA_NUM_PARALLEL = 131072
  # tokens: 13040 MiB of VRAM for a 2.3 GiB model, 9792 MiB of it KV cache.
  # With the window set on the model it is 3146 MiB. 4096 is ample. IRIS
  # truncates everything it adds to the prompt (git status/diff, --help) to a
  # few thousand characters.
  #
  # Created through the API rather than a Modelfile + `ollama create`, which
  # would need the CLI to find the server. Re-creating an identical model is
  # a no-op, so this can run on every boot. A missing base model (fresh
  # machine, ollama-model-loader still pulling) makes the create fail and the
  # unit retry. Note that services.ollama.syncModels = true would delete this
  # model, because it is not in loadModels.
  systemd.services.ollama-iris-model = {
    description = "Create the small-context ollama model used by IRIS";
    wantedBy = [
      "multi-user.target"
      "ollama.service"
    ];
    after = [
      "ollama.service"
      "ollama-model-loader.service"
    ];
    bindsTo = [ "ollama.service" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      ${pkgs.curl}/bin/curl -sSf --retry 10 --retry-connrefused --retry-delay 2 \
        http://127.0.0.1:${toString config.services.ollama.port}/api/create \
        -d '{"model":"iris-qwen3-4b","from":"qwen3:4b-instruct-2507-q4_K_M","parameters":{"num_ctx":4096},"stream":false}'
    '';
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
