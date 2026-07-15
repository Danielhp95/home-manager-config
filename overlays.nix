final: prev: {
  # Build whisper-cpp with CUDA support for RTX 5090
  whisper-cpp = prev.whisper-cpp.override {
    cudaSupport = true;
    cudaPackages = prev.cudaPackages;
  };
}
