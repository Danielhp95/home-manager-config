# Upgrade checklist

What to look at when an input or nixpkgs moves. A build that passes is not
enough for these: lnav, yazi, television and IRIS ignore keys they do not know
without a word, and the patches below only fail the build when an anchor moves.

| When this moves | Look at | In |
|---|---|---|
| nixpkgs' yazi | The yazi-rs/plugins pin must track yazi's version: the plugin API is versioned and a mismatch only fails at runtime. | `home/yazi/default.nix` (`officialPlugins`) |
| nixpkgs' yazi | Theme keys. An unknown or renamed key silently reverts to the preset (v26 moved the hover styles from `[mgr]` to `[indicator]`). | `home/yazi/theme.nix` |
| IRIS (`iris` input, pinned) | Upstream pins a vendorHash, so an update that changes go.mod without bumping it fails to build: re-pin the previous rev. | `flake.nix` |
| IRIS | Re-read the control flow around each `--replace-fail` anchor, and re-diff the hook half of `iris init zsh` (root/init.go). An unknown config or theme key is ignored without a word. | `home/terminal/iris.nix` |
| lnav | Keep the theme's keys equal to the union of the bundled themes (`~/.config/lnav/configs/default/*.json.sample`; 43/26/15/4 per section as of 0.14.1). lnav does not validate a theme. | `home/lnav.nix` |
| television | `theme_overrides` holds every key tv 0.15.9's ThemeOverrides accepts; unknown names are ignored. | `home/terminal/television.nix` |
| tmux-continuum | The patch deletes two calls and the build fails if either moves: re-read `continuum.tmux` then. | `home/tmux/default.nix` |
| nixpkgs | Move the `pkgs.multiverse.at "<date>"` date along with it (grayjay). | `home/apps.nix` |
| IPython | The traceback colouring rebinds private names (`ultratb.get_style_by_name`, `VerboseTB._tb_highlight_style`). It is wrapped in try/except, so a rename shows only as wrong colours. | `home/ipython/ipython_config.py` |
| Hyprland, hy3 | Pin both revs and move them together, to a Hyprland rev hy3 supports. | `flake.nix` |
| noctalia | Re-check the hand-written plugin API definitions; a stale entry type-checks and then fails at runtime. | `home/noctalia/noctalia.d.luau` |
| kernel, GRUB | A generation with its own kernel costs about 116 MB of the 1 GB ESP; `configurationLimit` and `nh`'s `--keep` are sized for that. | `hosts/lenovo/hardware.nix`, `nixos/esp-check.nix` |
