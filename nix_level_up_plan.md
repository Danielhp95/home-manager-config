# Nix Config Level-Up Plan (25.11 → 26.05)

Status legend: ☐ todo · ☑ done · ⏭ deferred

---

## Part 1 — Evaluation warnings

Three of the six warnings are gated on `home.stateVersion` (currently `"24.05"` in `home.nix:13`).
NixOS keeps the old behavior for you until you bump it — so those are informational.

**Strategy:** keep `stateVersion` as-is and pin the legacy values explicitly (zero behavior
change). Do **not** bump `stateVersion` just to silence warnings — it encodes data-migration
semantics. Adopt new 26.05 defaults only where deliberately wanted.

The duplicate warning counts (4×, 2×) come from the two HM users `dani` + `dev`, times the
roadwarrior specialisation. Fixing each source once clears every copy.

| # | Warning | Source | Fix | Status |
|---|---------|--------|-----|--------|
| 1 | `hyprland.configType` default `hyprlang` → `lua` | `hyprland/default.nix:31`, `specialisations/roadwarrior.nix:5` | Add `configType = "hyprlang";` (config is hyprlang; lua migration deferred) | ☐ |
| 2 | `yazi.shellWrapperName` `"yy"` → `"y"` | `yazi/default.nix:16` | Add `shellWrapperName = "yy";` to keep muscle memory | ☐ |
| 3 | `gtk.gtk4.theme` `config.gtk.theme` → `null` | `hyprland/theming.nix:6` | Add `gtk.gtk4.theme = config.gtk.theme;` (needs `config` in arg list) | ☐ |
| 4 | `'system'` renamed → `stdenv.hostPlatform.system` | `danvim/flake.nix:359` | `pkgs.system` → `pkgs.stdenv.hostPlatform.system` (re-lock danvim after) | ☐ |
| 5 | `zsh.dotDir` relative paths deprecated | `zsh/default.nix:85` | `dotDir = "${config.xdg.configHome}/zsh";` (needs `config` in arg list) | ☐ |

Order: do #4 and #5 (real deprecations) first; #1–#3 are keep-legacy one-liners.

---

## Part 2 — Redundancy to remove

### Dead / commented code (safe deletions)
- `flake.nix`: 11 (old HM URL), 92 (dup `fell-omen =`), 99 (`./fcitx5`), 101 (nixos-hardware),
  109 (crowdstrike), 167 (hyprtasking — input doesn't exist)
- `home.nix`: 97–99 (slack wrapper), 109 (ansel), 139 (grayjay), 165 (danvim stable),
  220–227 (voxtype systemd dropin)
- `zsh/default.nix`: 57–82 (abandoned starship multiline fix)
- `hyprland/default.nix`: 34, 37, 53

### Duplicate packages
- `imv` + `mpv` — in both `home.nix:135,142` and `hyprland/default.nix:71-72` → keep `home.nix`, drop from hyprland
- `bat` — in both `home.nix:118` and `zsh/default.nix:17` → keep one

### Stray / untracked cruft (delete)
- `test.nu`, `todo` (old warnings dump), `non_home_manager_config/configuration_old.nix`,
  `.Trash-1000/`, `wallpapers/test.lua`

### Orphaned module dirs (never imported)
- `vicinae/` (empty), `i3/`, `niri/`, `sway/` → archive to a branch or delete

### Structural redundancy
- `dev` user duplicates `dani` (identical `./home.nix` import in `flake.nix`)
- `unstable` input == `nixpkgs` input (both `nixos-unstable`); plus `channels` overlay does the same job
- `allowUnfree` set three ways; channels-overlay path doesn't inherit it (blocks pure eval)

---

## Part 3 — Cleaner setup (structural, highest leverage first)

1. **Add a formatter, run once.** `formatter.x86_64-linux = nixfmt-rfc-style;` then `nix fmt`.
2. **Factor `dani`/`dev` duplication.** Parameterize `home.nix` by username or split base + overrides.
3. **Centralize `pkgs` variants.** Pick ONE of `channels` overlay vs `*WithUnfree` imports, not both.
4. **Consolidate package lists by concern.** hyprland module = hyprland-only tools; rest → `home.nix`.
5. **Prune orphaned WM modules** (`i3`, `niri`, `sway`, `vicinae`) — archive on a branch.

---

## Execution log
- 2026-06-22: Plan created. Selected scope: **warnings + dead-code cleanup** (Parts 1 & 2).
  Structural changes (Part 3) deferred pending review.
