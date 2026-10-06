# Font families by role (fontconfig names), the counterpart of palette/;
# `packages` provides them. Consumers read them as `theme.fonts`; the `fonts`
# check (lib/checks.nix) holds every name here against the font packages.
# GRUB's and the start page's display fonts are deliberate one-offs.
{
  # UI text: GTK/Qt, noctalia, fcitx5 and fontconfig's sans-serif.
  ui = "Adwaita Sans";
  uiSize = 11;

  # Cell-grid text: terminals, hy3 tabs, wl-kbptr, fontconfig's monospace.
  # The Nerd Font "Mono" variant keeps icons one cell wide.
  mono = "JetBrainsMono Nerd Font Mono";
  # Icons at natural width, for mono text outside a cell grid (vicinae).
  monoWide = "JetBrainsMono Nerd Font";

  # fontconfig's serif, Latin included.
  serif = [
    "Source Han Serif SC"
    "Source Han Serif TC"
  ];
  # CJK fallback behind `ui`, for Chinese input.
  cjkSans = [
    "Source Han Sans SC"
    "Source Han Sans TC"
  ];

  emoji = "Noto Color Emoji"; # from fonts.enableDefaultPackages
  # Icon fallback for glyphs the main font lacks (kitty symbol_map).
  symbols = "Symbols Nerd Font Mono";

  packages =
    pkgs: with pkgs; [
      adwaita-fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      source-han-sans
      source-han-serif
      noto-fonts # broad script coverage, incl. Noto Sans Symbols 2 (kitty symbol_map)
      babelstone-han # Han characters beyond Source Han's set
    ];
}
