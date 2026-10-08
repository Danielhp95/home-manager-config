{
  pkgs,
  lib,
  config,
  ...
}:
{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda;
    environmentVariables = {
      # A q8_0 KV cache is half of f16's; it needs flash attention. (q8_0 is
      # near-lossless; q4_0 is not, and the setting is global, so it would hit
      # every model.)
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # One model, one request slot: this box serves a single editor. Every slot
      # reserves its own window, and qwen3.8 (a hybrid architecture) is run with
      # a single slot whatever this says ("model architecture does not currently
      # support parallel requests" in the journal), so this just states it.
      # Measured with these settings: qwen3.8:27b at the 64k window below is
      # 16.3 GiB in `ollama ps`, all of it in VRAM, about 20.6 of the card's
      # 24 GiB in use once the buffers are counted.
      #
      # IRIS's model is deliberately not kept beside it. That leaves no honest
      # room for a second model (its 4B needs ~3 GiB), so loading either evicts
      # the other whatever MAX_LOADED_MODELS says; with IRIS's AI unused that
      # costs nothing. If it is ever used again, expect the big model to reload
      # (and its prompt cache to go) whenever IRIS asks.
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      # The default 5 minutes unloaded the model between thoughts, and every
      # reload also threw away the prompt cache, so the next turn re-read the
      # whole conversation. CodeCompanion sends the same value per request
      # (danvim.ollama), so that is what actually applies while it is in use.
      OLLAMA_KEEP_ALIVE = "30m";
      # A load takes ~7 s from the page cache and ~30 s cold from disk (measured
      # for qwen3.8:27b); anything much longer is stuck.
      OLLAMA_LOAD_TIMEOUT = "5m";
      # Window for requests without num_ctx (ollama would pick 32k). Keep equal
      # to num_ctx in danvim's CodeCompanion config: a request with a different
      # num_ctx makes ollama restart the runner. (On the previous model,
      # qwen3-coder, 64k cost no speed against 32k and 128k cost ~27%.)
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
    loadModels = [
      "qwen3.8:27b" # Local development (danvim.ollama.profile)
      "qwen3:4b-instruct-2507-q4_K_M" # IRIS
    ];
  };

  # The unit ships without a restart policy, so a crash of the llama-server
  # runner's parent (upstream has open sm_120 bugs) leaves ollama down until
  # someone notices.
  systemd.services.ollama.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "5s";
  };

  # iris-qwen3-4b: the IRIS model with num_ctx 4096 baked in; ollama's OpenAI
  # endpoint (all IRIS speaks) ignores num_ctx, so the plain tag loads at 128k
  # tokens (~13 GiB). Created via the API each boot (idempotent, retries until
  # the base model is pulled); services.ollama.syncModels would delete it.
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
      ${lib.getExe pkgs.curl} -sSf --retry 10 --retry-connrefused --retry-delay 2 \
        http://127.0.0.1:${toString config.services.ollama.port}/api/create \
        -d '{"model":"iris-qwen3-4b","from":"qwen3:4b-instruct-2507-q4_K_M","parameters":{"num_ctx":4096},"stream":false}'
    '';
  };
}
