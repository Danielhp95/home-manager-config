# nix_config

One NixOS machine and its one user: a flake with Home Manager as a NixOS
module.

## Map

| Path | What it holds |
|---|---|
| `flake.nix` | Inputs, the host list, `nix fmt`, the checks, the packages worth building alone |
| `hosts/lenovo/` | What only this machine has: hardware, its boot entries, its speakers' EQ. The directory name is the host name |
| `nixos/` | System modules (`default.nix` is the list) |
| `home/` | Home Manager modules (`default.nix` is the list); one file or directory per program |
| `pkgs/` | `overlay.nix`, the one list of what this flake adds to nixpkgs or changes in it, and the packages more than one module needs |
| `palette/` | The colour palettes; `default.nix` selects one in a line |
| `fonts.nix` | The font families, once |
| `lib/` | Colour helpers |
| `docs/` | `manual-steps.md` (what a rebuild cannot do), `upgrade-checklist.md` (what to re-check on a bump) |
| `wallpapers/` | Read by noctalia from the checkout, not from the store |
| `danvim/` | The Neovim config: a separate repository, ignored here, a `path:` input |

## Conventions

- Names are kebab-case. A module is `<name>.nix` until it has sibling files and
  `<name>/default.nix` after. A derivation written here is `package.nix`, called
  with `callPackage`, beside the module that uses it.
- A module is on because it is imported. There are no enable flags and no
  options for constants.
- Import lists are explicit, and their order is part of the build: it decides
  the order of `home.packages` and `environment.systemPackages`. Add new
  modules at the end, and reorder in a commit of its own.
- A package from a flake input, or a patched nixpkgs package, is bound once in
  `pkgs/overlay.nix` and used as `pkgs.<name>`.
- New scripts are Nushell files run through `pkgs.writers.writeNu`.
- A workaround's comment says why it exists and when it can go.

## Working on it

```sh
nix fmt                      # deadnix, then nixfmt
nix flake check              # palettes, nixfmt, statix, deadnix
nh os build                  # build without switching
```

A refactor that should change nothing is proven by the system derivation
staying the same (about 35 s):

```sh
nix eval --raw .#nixosConfigurations.lenovo.config.system.build.toplevel.drvPath
```

Three things it cannot see, or sees too well:

- **List order is output.** Reordering an import list changes
  `home-manager-path` or `system-path` though nothing a user can notice moves.
- **Quoted text is output.** A repo path written inside a generated file is
  content.
- **Runtime paths are invisible.** The dart plugin, noctalia's Luau
  definitions and the wallpapers are read from `~/nix_config` by path; moving
  them breaks the running session with the derivation unchanged.
