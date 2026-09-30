{
  pkgs,
  config,
  ...
}:
{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda;
    environmentVariables = {
      # A q8_0 KV cache is half of f16's, which pays for the 64k window below;
      # it needs flash attention.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # Two models resident (IRIS's beside a bigger one), two request slots
      # each. Every slot reserves its own window, doubling the KV cache:
      # qwen3-coder:30b at 64k then spills ~1.7 GiB to CPU.
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_LOAD_TIMEOUT = "15m";
      # Window for requests without num_ctx (ollama would pick 32k): 64k costs
      # no speed; 128k costs ~27% (measured with one request slot).
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
    loadModels = [
      "qwen3-coder:30b"  # Local development
      "qwen3:4b-instruct-2507-q4_K_M"  # IRIS
    ];
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
      ${pkgs.curl}/bin/curl -sSf --retry 10 --retry-connrefused --retry-delay 2 \
        http://127.0.0.1:${toString config.services.ollama.port}/api/create \
        -d '{"model":"iris-qwen3-4b","from":"qwen3:4b-instruct-2507-q4_K_M","parameters":{"num_ctx":4096},"stream":false}'
    '';
  };
}
