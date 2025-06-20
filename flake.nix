{
  description = "Sony AI developmenet setup home-manager flake";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    zoomStable.url = "github:nixos/nixpkgs?rev=ba60e197b7dd7dd88b498bce0cc712952ccdbaf1";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      # version 0.49
      rev = "0ac3bef72473c619194514d01ca55f2ed8c617c3";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hy3 = {
      type = "git";
      url = "https://github.com/outfoxxed/hy3/";
      # 0.49
      rev = "567dc9dd20e15d95a56a81c516a70dba30bc2c9c";
      submodules = true;
      inputs.hyprland.follows = "hyprland";
    };
    # https://github.com/raybbian/hyprtasking
    hyprtasking = {
      url = "github:raybbian/hyprtasking";
      inputs.hyprland.follows = "hyprland";
    };
    television = {
      url = "github:alexpasmantier/television";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    yazi = {
      url = "github:sxyazi/yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # For a specific release
    # home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    danvim.url = "path:/home/daniel/nix_config/danvim";
    danvim.inputs.nixpkgs.follows = "nixpkgs";

    haumea.url = "github:nix-community/haumea";
    haumea.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      nixpkgs,
      stable,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      stableWithUnfree = import stable {
        config = {
          allowUnfree = true;
        };
        inherit system;
      };
      zoomStableWithUnfree = import inputs.zoomStable {
        config = {
          allowUnfree = true;
        };
        inherit system;
      };
      unstableWithUnfree = import inputs.unstable {
        config = {
          allowUnfree = true;
        };
        inherit system;
      };
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        fell-omen = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs unstableWithUnfree;
          }; # Pass flake inputs to our config
          # > Our main nixos configuration file <
          modules = [
            # ./fcitx5
            home-manager.nixosModules.default # Otherwise home-manager isn't imported
            inputs.nixos-hardware.nixosModules.omen-16-n0005ne
            ./hardwares/fell_omen.nix

            ./non_home_manager_config/configuration.nix
            ./non_home_manager_config/gestures.nix
            ./non_home_manager_config/ollama.nix
            ./non_home_manager_config/network.nix
            ./pipewire.nix

            # ./crowdstrike/falcon.nix

            # Specialisations
            ./specialisations/roadwarrior.nix
            {
              home-manager = {
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules = [
                  ./swww/swww.nix
                  ./hyprland/pyprland.nix
                ];
                extraSpecialArgs = {
                  inherit
                    inputs
                    stableWithUnfree
                    unstableWithUnfree
                    zoomStableWithUnfree
                    ;
                };
                users.daniel =
                  { config, ... }:
                  {
                    imports = [ ./home.nix ];
                  };
              };
            }
            # overlays
            {
              nixpkgs.overlays = with nixpkgs.lib; [
                (final: prev: {
                  # load in inputs and provide as `channels` attribute in `pkgs.channels`
                  channels = pipe inputs [
                    (filterAttrs (
                      name: _:
                      elem name [
                        "nixpkgs"
                        "unstable"
                      ]
                    ))
                    (mapAttrs (_: c: c.legacyPackages.${prev.system}))
                  ];

                  television = inputs.television.packages.${prev.system}.default;
                  inherit (inputs.yazi.packages.${prev.system}) yazi;
                  # Hyprland specifics
                  inherit (inputs.hy3.packages.${prev.system}) hy3;
                  inherit (inputs.hyprtasking.packages.${prev.system}) hyprtasking;
                  inherit (inputs.hyprland.packages.${prev.system})
                    hyprland
                    xdg-desktop-portal-hyprland
                    hyprland-share-picker
                    ;
                })
                (import ./overlays.nix)
              ];
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages = [
                "electron-25.9.0"
                "zoom"
              ];
              # allows running packages from `nix run unstable#ansel`
              # `nix run nixos#lsd` is very fast as it uses local cache
              nix.registry = {
                nixos.flake = inputs.nixpkgs;
                stable.flake = inputs.stable;
              };
            }
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        "daniel@fell-omen" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = {
            inherit inputs;
          }; # Pass flake inputs to our config
          modules = [
            ./home.nix
            {
              # Inlining an attribute set
              nix.registry = {
                nixos.flake = inputs.nixpkgs;
                unstable.flake = inputs.unstable;
              };
            }
          ];
        };
      };
    };
}
