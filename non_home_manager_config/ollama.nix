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
      # Quantize the KV cache instead of the default f16, so context doesn't
      # eat into the ~4GB left over after the 20GB Q4_K_XL weights on a 24GB
      # card. Needs flash attention to be on.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # Keep the whole 24GB budget for one model/request at a time instead of
      # splitting VRAM across concurrent loads or parallel request slots.
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
    };
    loadModels = [
      # Unsloth's Dynamic 2.0 quant of the biggest dense Qwen3 that still
      # fits a 24GB card: https://unsloth.ai/docs/models/qwen3-how-to-run-and-fine-tune
      # UD-Q4_K_XL weights are ~20GB, leaving ~4GB of VRAM headroom for the
      # (quantized) KV cache above. `ollama pull` understands hf.co refs
      # directly, no GGUF download/conversion step needed.
      "hf.co/unsloth/Qwen3-32B-GGUF:UD-Q4_K_XL"
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
