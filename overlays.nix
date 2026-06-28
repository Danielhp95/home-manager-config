final: prev: {
  __dontExport = true; # overrides clutter up actual creations

  # To have all nice tree-sitter grammars
  nvimbundle = prev.neovimBuilder (import ./nvim/neovim-pkg.nix prev);
  logseq = (final.channels.unstable.logseq.override {
    electron_27 = final.channels.nixpkgs.electron_27;
  });
  # Build whisper-cpp with CUDA support for RTX 5090
  whisper-cpp = prev.whisper-cpp.override {
    cudaSupport = true;
    cudaPackages = prev.cudaPackages;
  };
}
