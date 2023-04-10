{
  description = "Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    homeManager.url = "github:nix-community/home-manager";
    homeManager.inputs.nixpkgs.follows = "nixpkgs";

    nix2vim.url = "github:gytis-ivaskevicius/nix2vim?rev=f3b56da72278cd720fe7fb4b6d001047b7179669";
    nix2vim.inputs.nixpkgs.follows = "nixpkgs";

    # Should figure out how to set these
    nvfetcher.url = "github:berberman/nvfetcher";
    nvfetcher.inputs.nixpkgs.follows = "nixpkgs";

    # TODO: remove this when finished
    imagine-nvim = {
      url = "path:/home/daniel/Projects/imagine.nvim";
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, nix2vim, nvfetcher, homeManager, imagine-nvim}: {
      homeConfigurations = {
        "daniel@fell-omen" = homeManager.lib.homeManagerConfiguration {
          # pkgs = nixpkgs.legacyPackages.x86_64-linux;
          pkgs = import nixpkgs {
            overlays = [
                nix2vim.overlay
                (import ./pkgs)
                (import ./overlays.nix)
                # imagine-nvim.overlay
                # The overlay from imagine-nvim should replicate this behaviour
                (final: prev: {
                  vimPlugins = prev.vimPlugins // {
                    # TODO: remove this!
                      imagine-nvim = prev.vimUtils.buildVimPlugin {
                        name = "imagine-nvim";
                        src = inputs.imagine-nvim;
                      };
                    };
                })
              ];
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          modules = [
            ./home.nix
          ];
        };
      };
    };
}
