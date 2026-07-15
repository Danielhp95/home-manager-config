{
  description = "Personal system flake";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-26.05";
    # Alias of nixpkgs kept for `pkgs.channels.unstable` / `nix run unstable#...`
    unstable.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ### hyprlad
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      # v0.55.0 tag. Pinned because hyprland main regularly breaks hy3's
      # compile; when bumping, keep in sync with what hy3 supports.
      rev = "30983d6ff0ed5fc614daf3178ad311aa45f8d9e1";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      type = "git";
      url = "https://github.com/outfoxxed/hy3/";
      # 0.55.0
      rev = "aeaf7669607952bbcf25ca33433966b6a1b4563d";
      submodules = true;
      inputs.hyprland.follows = "hyprland";
    };

    noctalia = {
      type = "git";
      url = "https://github.com/noctalia-dev/noctalia";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-preview-share-picker = {
      type = "git";
      url = "https://github.com/WhySoBad/hyprland-preview-share-picker";
      rev = "344394a8669fb82ff2744d2780327dd402ffb76a";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    danvim.url = "path:/home/dani/nix_config/danvim";
    danvim.inputs.nixpkgs.follows = "nixpkgs";

    voxtype.url = "github:peteonrails/voxtype";
    voxtype.inputs.nixpkgs.follows = "nixpkgs";

    # CloudBrink BrinkAgent VPN packaging (kept out of git; pulled in as source).
    brinkagentSrc = {
      url = "path:/home/dani/Projects/brinkagent";
      flake = false;
    };
  };
  outputs =
    {
      nixpkgs,
      stable,
      home-manager,
      ...
    }@inputs:
    let
      # Shared between the NixOS-managed home-manager and the standalone entrypoint
      overlays = with nixpkgs.lib; [
        inputs.claude-code.overlays.default
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
            (mapAttrs (_: c: c.legacyPackages.${prev.stdenv.hostPlatform.system}))
          ];

          # Hyprland specifics
          inherit (inputs.hy3.packages.${prev.stdenv.hostPlatform.system}) hy3;
          inherit (inputs.hyprland.packages.${prev.stdenv.hostPlatform.system})
            hyprland
            xdg-desktop-portal-hyprland
            ;
        })
        (import ./overlays.nix)
      ];
      hmSharedModules = [
        inputs.noctalia.homeModules.default
        ./hyprland/pyprland.nix
      ];
      hmExtraSpecialArgs = {
        inherit inputs;
      };
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        fell-omen = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          }; # Pass flake inputs to our config
          # > Our main nixos configuration file <
          modules = [
            home-manager.nixosModules.default # Otherwise home-manager isn't imported
            ./hardwares/new_fell_omen.nix

            ./non_home_manager_config/configuration.nix
            ./non_home_manager_config/ollama.nix
            ./non_home_manager_config/network.nix
            ./non_home_manager_config/salt.nix
            ./pipewire.nix

            # CloudBrink BrinkAgent VPN (daemons + GUI). See /home/dani/Projects/brinkagent.
            (inputs.brinkagentSrc + "/module.nix")
            { services.brinkagent.enable = true; }

            # Specialisations
            ./specialisations/roadwarrior.nix
            {
              users.users.dev = {
                isNormalUser = true;
              };
              home-manager = {
                backupFileExtension = "backup";
                # Something (likely Hyprland's lua config reload) re-copies
                # hyprland.lua out of the store after each switch, leaving a stale
                # .backup that would otherwise abort the next activation.
                overwriteBackup = true;
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules = hmSharedModules;
                extraSpecialArgs = hmExtraSpecialArgs;
                users.dani =
                  { config, ... }:
                  {
                    imports = [
                      ./home.nix
                    ];
                  };
                users.dev =
                  { config, ... }:
                  {
                    imports = [ ./home.nix ];
                  };
              };
            }
            # overlays
            {
              nixpkgs.overlays = overlays;
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;
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
          # Same overlays/config as the NixOS-managed pkgs instance
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            inherit overlays;
          };
          extraSpecialArgs = hmExtraSpecialArgs;
          modules = hmSharedModules ++ [
            ./home.nix
            {
              # Set automatically by the NixOS module, needed here in standalone mode
              home.username = "dani";
              home.homeDirectory = "/home/dani";
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
