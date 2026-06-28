{ config, pkgs, ... }:

{
  ########################################
  # Packages
  ########################################
  environment.systemPackages = with pkgs; [
    voxtype
    whisper-cpp
    wl-clipboard
    libnotify
    sox
  ];

  ########################################
  # Voxtype configuration (env vars)
  ########################################
  environment.variables = {
    VOXTYPE_BACKEND = "whisper.cpp";
    VOXTYPE_MODEL = "base.en"; # change to small.en if you want better accuracy
  };

  ########################################
  # uinput (required for typing on Wayland)
  ########################################
  boot.kernelModules = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input"
  '';

  users.users.dani = {
    extraGroups = [ "input" ];
  };

  ########################################
  # PipeWire (low latency audio)
  ########################################
  services.pipewire = {
    enable = true;
    pulse.enable = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  ########################################
  # (Optional but recommended) security
  ########################################
  security.rtkit.enable = true;
}
