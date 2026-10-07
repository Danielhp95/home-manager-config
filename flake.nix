{
  description = "Personal system flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # Prebuilt database for programs.nix-index and comma (home/zsh/default.nix).
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    omnibin.url = "github:fzakaria/omnibin";
    omnibin.inputs.nixpkgs.follows = "nixpkgs";

    # Any nixpkgs release, date or commit on demand: (pkgs.multiverse.at "25.05").<name>
    # (pkgs/overlay.nix).
    multiverse.url = "github:fzakaria/nixpkgs-multiverse";

    # hy3 builds against Hyprland's headers: pin both revs and move them
    # together, to a Hyprland rev hy3 supports.
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      rev = "ae50c4d6bbbcb8ee7a0b0d89341a8e93fc9b99e7";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      type = "git";
      url = "https://github.com/elafarge/hy3/";
      rev = "378fb240479d631bed749554417cf9d12e5e0ef6";
      submodules = true;
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-preview-share-picker = {
      type = "git";
      url = "https://github.com/WhySoBad/hyprland-preview-share-picker";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      type = "git";
      url = "https://github.com/noctalia-dev/noctalia";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
    # Pinned: upstream is beta and pins a vendorHash, so an update that changes
    # go.mod without bumping it fails to build. Re-pin the previous rev then.
    iris = {
      type = "git";
      url = "https://github.com/versenilvis/IRIS";
      rev = "ac1cfe72820bbbb0f0eb3fb017a6b1e7f3fcb2fe";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Separate repo, gitignored here. A commit there reaches a rebuild only
    # after `nix flake update danvim`.
    danvim.url = "path:/home/dani/nix_config/danvim";
    danvim.inputs.nixpkgs.follows = "nixpkgs";
    danvim.inputs.stable.follows = "stable";

    # Claude Code skill collections, as plain sources;
    # home/claude-code/default.nix picks which skills to expose.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    socratic-skills = {
      url = "github:rodbv/socratic-skills";
      flake = false;
    };
    walkthrough-skill = {
      url = "github:alexanderop/walkthrough";
      flake = false;
    };
    codebase-to-course = {
      url = "github:zarazhangrui/codebase-to-course";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      # The selected palette, the fonts and the colour helpers (./theme.nix).
      theme = import ./theme.nix { inherit lib; };
      # The host's package set, overlay included: no second nixpkgs evaluation.
      inherit (self.nixosConfigurations.lenovo) pkgs;

      # The Nix files and the lint configuration only, so a lint check is
      # rebuilt when Nix code changes and not when a wallpaper does.
      nixSrc = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          (lib.fileset.fileFilter (f: f.hasExt "nix") ./.)
          ./statix.toml
        ];
      };
      lint =
        name: tools: cmd:
        pkgs.runCommand "lint-${name}" { nativeBuildInputs = tools; } ''
          cd ${nixSrc}
          ${cmd}
          touch $out
        '';
    in
    {
      # `nix fmt`: deadnix --edit, then nixfmt, over every tracked .nix file.
      formatter.${system} = pkgs.treefmt.withConfig {
        runtimeInputs = [
          pkgs.nixfmt
          pkgs.deadnix
        ];
        settings = {
          tree-root-file = "flake.nix";
          formatter.deadnix = {
            command = "deadnix";
            options = [ "--edit" ];
            includes = [ "*.nix" ];
            priority = 0;
          };
          formatter.nixfmt = {
            command = "nixfmt";
            includes = [ "*.nix" ];
            priority = 1;
          };
        };
      };

      # The derivations written in this repo that are worth building alone:
      # `nix build .#grub-theme`.
      packages.${system} = {
        inherit (pkgs) avatar danvim;
        grub-theme = pkgs.callPackage ./pkgs/grub-theme/package.nix { };
        start-page =
          (pkgs.callPackage ./home/firefox/firefox-start-page-wanderer/package.nix { inherit theme; }).page;
      };

      # `nix flake check`. Nothing runs these on its own: there is no CI.
      checks.${system} =
        # palettes (the GTK, cursor and icon themes each palette names exist)
        # and contrast.
        import ./palette/check.nix { inherit pkgs; }
        # references, fonts, and theme-<slug> for each palette not selected.
        // import ./lib/checks.nix {
          inherit pkgs lib theme;
          host = self.nixosConfigurations.lenovo;
        }
        // {
          nixfmt = lint "nixfmt" [ pkgs.nixfmt ] "find . -name '*.nix' -exec nixfmt --check {} +";
          # statix.toml switches off the one rule this repo does not follow.
          statix = lint "statix" [ pkgs.statix ] "statix check .";
          deadnix = lint "deadnix" [ pkgs.deadnix ] "deadnix --fail .";
        };

      overlays.default = import ./pkgs/overlay.nix { inherit inputs theme; };

      nixosConfigurations = nixpkgs.lib.genAttrs [ "lenovo" ] (
        hostName:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs hostName theme;
            # What more than one module needs to know about this machine.
            host = import ./hosts/${hostName}/facts.nix;
          };
          modules = [ ./hosts/${hostName} ];
        }
      );
    };
}
