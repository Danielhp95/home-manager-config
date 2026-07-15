final: prev: {
  __dontExport = true; # overrides clutter up actual creations

  # Build whisper-cpp with CUDA support for RTX 5090
  whisper-cpp = prev.whisper-cpp.override {
    cudaSupport = true;
    cudaPackages = prev.cudaPackages;
  };
}
