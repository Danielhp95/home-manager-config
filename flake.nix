{
  description = "Home Manager configurations";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stable.url = "github:NixOS/nixpkgs/release-22.11";
    homeManager.url = "github:nix-community/home-manager";
    homeManager.inputs.nixpkgs.follows = "nixpkgs";

    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";

    nix2vim.url = "github:gytis-ivaskevicius/nix2vim?rev=f3b56da72278cd720fe7fb4b6d001047b7179669";
    nix2vim.inputs.nixpkgs.follows = "nixpkgs";


    haumea.url = "github:nix-community/haumea";
    haumea.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = inputs @ { self, nixpkgs, nixgl, nix2vim, stable, homeManager, haumea}:
  let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [
        nixgl.overlay
        nix2vim.overlay
        (import ./pkgs)
        (import ./overlays.nix)
      ];
    };
  in {
    homeConfigurations = {
      "daniel@fell-omen" = homeManager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          {  # Inlining an attribute set
            nix.registry = {
              nixos.flake = nixpkgs;
              stable.flake = stable;
            };
          }
        ];
      };
    };
  };
}
