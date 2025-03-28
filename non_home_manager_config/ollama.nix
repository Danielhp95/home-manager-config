## Ollama
{ config, inputs, unstableWithUnfree, ... }:
{
  services.ollama = {
    package = unstableWithUnfree.ollama;
    enable = true;
    # package = pkgs.ollama-rocm;
    host = "0.0.0.0";
    acceleration = "cuda";
    loadModels = [
      "phi4:14b"  # Good model that fits in 8GB of VRAM
      "nomic-embed-text"  # Small model for embedding text
    ];
  };

  services.open-webui = {
    # package = inputs.unstable.legacyPackages.x86_64-linux.open-webui;
    enable = true;
    stateDir = "/var/lib/open-webui";
    host = "0.0.0.0";
    # options: https://docs.openwebui.com/getting-started/advanced-topics/env-configuration
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
    };
  };
}
