## Ollama
{ pkgs, config, inputs, unstableWithUnfree, ... }:
{
  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda;
    loadModels = [
      "phi4:14b"  # Good model that fits in 8GB of VRAM
    ];
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    # options: https://docs.openwebui.com/getting-started/advanced-topics/env-configuration
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
    };
  };
}
