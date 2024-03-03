{
  description = "Config and dotfiles for personal NixOS laptop.";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-23.11";
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
          home-manager.nixosModules.default  # Otherwise home-manager isn't imported
          { 
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.daniel = { config, ...}: {
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
                  (filterAttrs (name: _: elem name [ "nixpkgs" "unstable" ]))
                  (mapAttrs (_: c: c.legacyPackages.${prev.system}))
                ];
                # override specific packages from unstable
                inherit (final.channels.unstable) ansel;
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
