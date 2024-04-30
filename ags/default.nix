{ inputs, pkgs, ... }:
{
  imports = [
    inputs.ags.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    material-symbols  # icons
    ollama
    pywal
    sassc

    ydotool
    identity  # For music app

    # For video recording
    slurp
    wf-recorder

    # Color picker
    hyprpicker
  ];

  programs.ags = {
    enable = true;
    configDir = ./ags_config; # if ags dir is managed by home-manager, it'll end up being read-only. not too cool.
    # configDir = ./.config/ags;

    extraPackages = with pkgs; [
      gtksourceview
      gtksourceview4
      ollama
      (python311.withPackages (p: [
        p.material-color-utilities
        p.pywayland
        p.identify
      ]))
      pywal
      sassc
      webkitgtk
      webp-pixbuf-loader
      ydotool
    ];
  };
}
