{
  description = "Personal system flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # Prebuilt database for programs.nix-index and comma (zsh/default.nix).
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    omnibin.url = "github:fzakaria/omnibin";
    omnibin.inputs.nixpkgs.follows = "nixpkgs";

    # hy3 builds against Hyprland's headers: pin both revs and move them
    # together, to a Hyprland rev hy3 supports.
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      rev = "4bb6844b0351e4fbf2e3d4e46ae71b551a0e0a42";
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

    # Claude Code skill collections, as plain sources; claude_code/default.nix
    # picks which skills to expose.
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
    { nixpkgs, ... }@inputs:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      nixosConfigurations.lenovo = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./hardwares/lenovo_t16g_gen3.nix
          ./non_home_manager_config/configuration.nix
        ];
      };
    };
}
