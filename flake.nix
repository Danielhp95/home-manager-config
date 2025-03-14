{
  description = "Sony AI developmenet setup home-manager flake";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    basedpyright_stable.url =
      "github:nixos/nixpkgs?rev=2893f56de08021cffd9b6b6dfc70fd9ccd51eb60";
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      # version 0.47.2
      rev = "7753e8ea686ba0aeaa825502f27e5b3f813faade";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      type = "git";
      url = "https://github.com/outfoxxed/hy3/";
      # 0.47
      rev = "833c52e642afbf6a5a95a078580a0fbce118848f";
      submodules = true;
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-easymotion = {
      url = "github:BowlBird/hyprland-easymotion";
      inputs.hyprland.follows = "hyprland";
    };

    # https://github.com/raybbian/hyprtasking
    # Better workspace plugin to try!
    hyprtasking = {
      url = "github:raybbian/hyprtasking";
      inputs.hyprland.follows = "hyprland";
    };

    hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    danvim.url = "path:/home/daniel/nix_config/danvim";
    danvim.inputs.nixpkgs.follows = "unstable";

    haumea.url = "github:nix-community/haumea";
    haumea.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, stable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      stableWithUnfree = import stable {
        config = { allowUnfree = true; };
        inherit system;
      };
      unstableWithUnfree = import inputs.unstable {
        config = { allowUnfree = true; };
        inherit system;
      };
    in {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        fell-omen = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; }; # Pass flake inputs to our config
          # > Our main nixos configuration file <
          modules = [
            # ./fcitx5
            home-manager.nixosModules.default # Otherwise home-manager isn't imported
            ./hardwares/fell_omen.nix
            ./non_home_manager_config/configuration.nix
            ./non_home_manager_config/gestures.nix
            ./non_home_manager_config/ollama.nix
            ./pipewire.nix

            # Specialisations
            ./specialisations/roadwarrior.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules =
                  [ ./swww/swww.nix ./hyprland/pyprland.nix ];
                extraSpecialArgs = { inherit inputs stableWithUnfree unstableWithUnfree; };
                users.daniel = { config, ... }: { imports = [ ./home.nix ]; };
              };
            }
            # overlays
            {
              nixpkgs.overlays = with nixpkgs.lib; [
                (final: prev: {
                  # load in inputs and provide as `channels` attribute in `pkgs.channels`
                  channels = pipe inputs [
                    (filterAttrs (name: _: elem name [ "nixpkgs" "unstable" ]))
                    (mapAttrs (_: c: c.legacyPackages.${prev.system}))
                  ];
                  # override specific packages from unstable
                  # inherit (final.channels.unstable) ansel wezterm;

                  # Hyprland specifics
                  inherit (inputs.hy3.packages.${prev.system}) hy3;
                  inherit (inputs.hyprland.packages.${prev.system})
                    hyprland xdg-desktop-portal-hyprland hyprland-share-picker;
                })
                (import ./overlays.nix)
              ];
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages =
                [ "electron-25.9.0" "zoom" ];
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
        "dani@fell-omen" = home-manager.lib.homeManagerConfiguration {
          pkgs =
            nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
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
