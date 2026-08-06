{
  description = "Personal system flake";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ### hyprlad
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      rev = "91f29f23bb691462f8aa6171b964069aebc37910";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      type = "git";
      url = "https://github.com/outfoxxed/hy3/";
      rev = "42b7ed8fd9aefd3f36e5f617afd5071245c67853";
      submodules = true;
      inputs.hyprland.follows = "hyprland";
    };

    hyprland-preview-share-picker = {
      type = "git";
      url = "https://github.com/WhySoBad/hyprland-preview-share-picker";
      rev = "e2f30ff85486e557018523da45ccbc846e3a499c";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };


    noctalia = {
      type = "git";
      url = "https://github.com/noctalia-dev/noctalia";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned Firefox add-on XPIs, exposed as `pkgs.firefox-addons.*` by its
    # overlay below and consumed by firefox/default.nix.
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Patches Spotify's Electron bundle so it can be themed (see spotify.nix).
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";

    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # IRIS: IntelliSense-style completion overlay. Its own flake exposes
    # packages.<system>.iris (buildGoModule), re-exported as `pkgs.iris` by the
    # overlay below. Upstream is beta and pins a vendorHash, so a `nix flake
    # update iris` that lands a go.mod change without a matching vendorHash
    # bump will fail the build — re-pin to the previous rev if that happens.
    iris = {
      type = "git";
      url = "https://github.com/versenilvis/IRIS";
      rev = "994ff836752bf4c5246a3aec236dd597421dccf0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      overlays = [
        inputs.claude-code.overlays.default
        inputs.firefox-addons.overlays.default
        (
          final: prev:
          let
            system = prev.stdenv.hostPlatform.system;

            hyprland = inputs.hyprland.packages.${system}.hyprland;
          in
          {
            # Shell completion overlay (terminal/iris.nix); not in nixpkgs
            inherit (inputs.iris.packages.${system}) iris;

            # Hyprland specifics. hy3 links against Hyprland's headers, so it has
            # to get the exact same build we install.
            inherit hyprland;
            hy3 = inputs.hy3.packages.${system}.hy3.override { inherit hyprland; };
            inherit (inputs.hyprland.packages.${system}) xdg-desktop-portal-hyprland;

            # espeak-ng pulls mbrola + mbrola-voices (~645 MB) by default. Nothing
            # here uses the external voice corpus, and espeak keeps its own built-in
            # voices, so speech-dispatcher/spd-say still work without it.
            espeak-ng = prev.espeak-ng.override { mbrolaSupport = false; };
          }
        )
      ];
      hmSharedModules = [
        inputs.noctalia.homeModules.default
        inputs.spicetify-nix.homeManagerModules.default
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
            ./non_home_manager_config/tailscale.nix
            # ./non_home_manager_config/salt.nix — Sony AI salt-minion; disabled
            # 2026-08-03: it error-looped every 30s unable to resolve its master.
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
                stable.flake = inputs.stable;
              };
            }
          ];
        };
      };
    };
}
