{
  description = "Config and dotfiles for personal NixOS laptop.";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    hyprcursor.url = "github:hyprwm/hyprcursor";
    hyprcursor.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland?ref=v0.36.0";
    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.36.0"; # where {version} is the hyprland release version
      inputs.hyprland.follows = "hyprland";
    };

    # Home manager
    home-manager.url = "github:nix-community/home-manager/";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";

    haumea.url = "github:nix-community/haumea";
    haumea.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs: {
    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      fell-omen = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs ;
        }; # Pass flake inputs to our config
        # > Our main nixos configuration file <
        modules = [
          ./hardwares/fell_omen.nix
          ./temp/configuration.nix
          ./pipewire.nix
          home-manager.nixosModules.default  # Otherwise home-manager isn't imported
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              sharedModules = [ ./swww/default.nix ];
              extraSpecialArgs = { inherit inputs; };
              users.daniel = { config, ...}: {
                imports = [ ./home.nix  ./swww/swww.nix ];
              };
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
                # inherit (final.channels.unstable) ansel wezterm eww;

                # Hyprland specifics
                inherit (inputs.hyprcursor.packages.${prev.system}) hyprcursor;
                inherit (inputs.hy3.packages.${prev.system}) hy3;
                # inherit (inputs.hy3.packages.${prev.system}) hy3;
                # inherit (inputs.hyprland.packages.${prev.system})
                #   hyprland
                #   xdg-desktop-portal-hyprland
                #   hyprland-share-picker
                #   ;
              })
              (import ./overlays.nix)
              (import ./pkgs)
            ];
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.permittedInsecurePackages = [
              "electron-25.9.0"
            ];
            # allows running packages from `nix run unstable#ansel`
            # `nix run nixos#lsd` is very fast as it uses local cache
            nix.registry = {
              nixos.flake = inputs.nixpkgs;
              unstable.flake = inputs.unstable;
            };
          }
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "dani@fell-omen" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {
          inherit inputs ;
        }; # Pass flake inputs to our config
        # > Our main home-manager configuration file <
        modules = [
            ./home.nix
	    {  # Inlining an attribute set
	      nix.registry = {
	        nixos.flake = inputs.unstable;
	        stable.flake = inputs.nixpkgs;
	      };
	    }
         ];
      };
    };
  };
}
