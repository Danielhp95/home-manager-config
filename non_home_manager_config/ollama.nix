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
    enable = false;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda;
    loadModels = [
      "phi4:14b" # Good model that fits in 8GB of VRAM
      "qwen3.6:27b"
      "gemma4:31b"
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
