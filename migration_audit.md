# What lives outside nix — pre-migration audit

Audited 2026-09-09 on `fell-omen`. The question this answers: if I `git clone`
this repo onto a fresh machine and `nh os switch`, what do I *not* get?

The good news first: there are **no imperative nix installs** (`nix profile
list` and `nix-env -q` are both empty), **nothing on `$PATH` outside the nix
store** except `/run/wrappers/bin`, and **no cargo / npm-global / go / pipx /
flatpak / AppImage installs at all**. `/opt` and `/usr/local` are empty. The
drift is concentrated in five places, listed worst-first.

---

## 1. Blockers — the flake will not evaluate on a fresh machine

Both are `path:` inputs pointing outside the repo's own git tree.

### `~/Projects/brinkagent` (flake input `brinkagentSrc`)

```nix
brinkagentSrc = {
  url = "path:/home/dani/Projects/brinkagent";
  flake = false;
};
```

Not a git repo — no remote, no history. Contains a **141 MB vendored
`BrinkAgent-latest2404.deb`** plus the nix packaging that unpacks it
(`default.nix`, `module.nix`, `daemon.nix`, wrapper scripts). The flake.nix
comment says "kept out of git; pulled in as source", so this was a deliberate
choice — but it means the directory has to be **copied by hand** to the new
machine, or the config is unbuildable.

Options, roughly in order of effort:
- Copy `~/Projects/brinkagent/` verbatim (simplest; keeps the 141 MB blob
  living outside version control forever).
- Make it a private git repo and switch the input to a git URL.
- Move the packaging into `nix_config/brinkagent/` and fetch the `.deb` with
  `requireFile` / `fetchurl` + hash, so only the recipe is versioned.

### `nix_config/danvim/` (flake input `danvim`)

`danvim/` is in `.gitignore` — it is a **separate git repo**
(`https://github.com/Danielhp95/danvim.git`, currently at `22c55ce`) consumed
as `path:/home/dani/nix_config/danvim`. Cloning `nix_config` alone gives you an
empty `danvim/` and no editor.

On the new machine: `git clone https://github.com/Danielhp95/danvim.git
nix_config/danvim` **before** the first build. Remember the two known traps —
new files must be `git add`ed to be visible to the flake, and a danvim commit
is invisible until `nix flake update danvim`.

---

## 2. Claude Code — nixified in part, by design

`claude_code/default.nix` manages: `CLAUDE.md`, four skills (brainstorming,
domain-modeling, grilling, grill-with-docs), all eleven LSP servers, and the
`claude-statusline` nushell script. That much comes across for free.

What does **not**:

| Thing | Why it's outside | Action |
|---|---|---|
| `~/.claude/settings.json` | Deliberate — Claude Code rewrites it at runtime, a store symlink would break those writes (documented in `claude_code/default.nix`) | **Copy by hand.** See below — it carries real config, not just state. |
| `~/.claude/skills/neovim-news-update` | Deliberate — writes `state.json` + `reports/` into its own dir, read-only store symlink would break it | Copy the directory, or accept losing its history |
| `~/.claude/plugins/` | Marketplace installs at runtime | Re-run: marketplace `anthropics/claude-plugins-official`, plugin `lua-lsp@1.0.0` |
| `~/.claude/.credentials.json` | Auth token | Re-login |
| `~/.claude.json`, `sessions/`, `history.jsonl`, `telemetry/`, `projects/`, `file-history/` | Pure runtime state (~100 KB + logs). No MCP servers configured, global or per-project — nothing hiding in here. | Nothing to do |

**`settings.json` is the one to actually care about.** It is not just UI
preferences; it holds:

- Seven **hook definitions** (SessionStart, UserPromptSubmit, PreToolUse,
  PostToolUse, Notification, Stop, SessionEnd) that all shell out to
  `$HOME/.local/state/noctalia/plugins/materialized/community/claude-companion/hooks/pulse.py`
  — see §3; **if that plugin isn't installed on the new machine, every hook
  fails on every turn.**
- The whole `autoMode` block: `allow` / `soft_deny` rules scoped to
  `~/Projects/sai`, plus a long hand-built `environment` briefing (org, cloud
  provider, trusted buckets, protected branches, secret names). That took real
  effort to produce and is not reconstructible from the repo.
- `attribution` set to empty commit/PR strings — the mechanism enforcing the
  no-Claude-attribution rule.
- Per-model effort levels, `editorMode: vim`, `theme: auto`, statusline wiring.

Since it can't be a store symlink, the realistic options are to copy it as part
of the migration, or to have home-manager write it **once**
(`home.activation` with a `[ -f ] ||` guard) so a fresh machine gets a seeded
copy that Claude Code is then free to rewrite.

---

## 3. Imperative extension stores

Programs that are themselves nix-installed, but that download their own
extensions at runtime into `~/.local/{share,state}`. None of this is declared.

**noctalia** (`~/.local/state/noctalia/`)
- `plugins/materialized/community/claude-companion` — the plugin the Claude
  hooks above depend on. Installed 2026-08-06.
- 64 `community-templates/`
- `community-palettes/One.json`
- Also unmanaged next to the nix-managed `config.toml`:
  `~/.config/noctalia/settings.json` (21 KB, last touched 2026-06-02 — likely
  stale since the move to `config.toml`), `colors.json`, `plugins.json`.

**vicinae** (`~/.local/share/vicinae/extensions/`) — 11 store extensions:
`awww-switcher`, `bluetooth`, `firefox`, `github`, `hypr-keybinds`,
`hyprland-monitors`, `nerdfont-search`, `nix`, `process-manager`, `pulseaudio`,
`systemd`. Plus `~/.config/vicinae/settings.json`. (The `nix` extension is the
one with the known index-rot problem.)

**Claude Code** — `lua-lsp` plugin, see §2.

---

## 4. Hand-maintained config files not in this repo

| Path | What it is |
|---|---|
| `~/.config/systemd/user/tmux.service` | Written write-once by tmux-continuum, not by nix. Known issue: its resurrect `ExecStop` path goes stale and silently kills save-on-logout. |
| `~/.gitconfig` | `gh auth setup-git` credential helpers, hardcoding `/etc/profiles/per-user/dani/bin/gh`. The rest of git config *is* nix-managed at `~/.config/git/config`. |
| `~/.config/git/ignore` | 31 bytes, sitting next to the nix-managed `config` |
| `~/.config/hypr/noctalia.conf`, `noctalia.lua`, `dgpu-mode` | Alongside the nix-managed `hyprland.lua` / `xdph.conf` |
| `~/.config/autostart/*.desktop` | 3 entries: `audio-recorder`, `Nextcloud`, and `BrinkAgentApp` — **the last one is dead**, it execs `/opt/BrinkAgent/BrinkAgentApp` and `/opt` is empty (history shows `sudo rm -rf /opt/BrinkAgent` after the nix packaging landed) |
| `~/.local/share/applications/*.desktop` | `Blue Prince`, `Hades II`, `Slay the Spire 2` (Steam-generated), `claude-code-url-handler` |
| `~/.fonts/` | `CustomTkinter_shapes_font.otf`, `Roboto-Medium.ttf`, `Roboto-Regular.ttf` |
| `~/.icons/Bibata-Modern-Amber` | Cursor theme |
| `~/.config/gh/{config,hosts}.yml` | gh CLI + its auth |

Everything else under `~/.config` that matters is a `/nix/store` symlink —
verified for atuin, bat, bottom, btop, discord, Element, fcitx5, fontconfig,
ghostty, git, gtk-3.0/4.0, hypr, imv, iris, kitty, lnav, mpv, noctalia,
nushell, pik, pistol, systemd, television, tmux, vicinae, yazi, zathura, zsh
(including all five zsh plugins).

---

## 5. Per-project toolchains

Not system-level, but they don't come from the repo either and every one needs
re-creating before work resumes.

- **`~/Projects/sai/.venv`** — provides `dart` (8 523 invocations in atuin, 158
  in the last 120 days) and `saic`. This is the single most-used non-nix
  command on the machine. Same for `~/Projects/sai_illum_v3/.venv` and
  `~/Projects/exact_systems/rewriter/.venv`.
- **uv-managed Pythons** — `cpython-3.12.10` and `cpython-3.14.2` under
  `~/.local/share/uv/python`, with `~/.local/bin/python3.12` symlinked into the
  3.12 one. That symlink is the *only* thing in `~/.local/bin`.
- **elan / Lean** — `~/.elan`, toolchain `leanprover--lean4---v4.31.0`.
  Consistent with `claude_code/default.nix` deliberately omitting `leanls`.

---

## 6. State and credentials to carry (not nixifiable)

`~/.ssh` (28 K) · `~/.gnupg` (84 K) · `~/.aws` (8 K) · `~/.docker` (4 K) ·
`~/.config/gh` · `~/.claude/.credentials.json` · `~/.local/share/keyrings`

Bulk state, decide case by case: atuin history **109 M** (the real shell
history — the zsh histfile is a rounding error next to it), `~/.mozilla`
**1.7 G**, Steam **24 G**, Grayjay **529 M**, DaVinciResolve **36 M**,
`~/.tmux/resurrect` (135 K of session snapshots).

---

## 7. Config leftovers from `nix run` — REMOVED 2026-09-09

These had `~/.config` directories but no declared package and no binary under
any name — residue from `nix run` experiments, confirmed against atuin history.

`audacity` · `broot` · `browsh` · `crush` · `Cursor` · `deluge` · `epiphany` ·
`eSearch` · `felix` · `fontforge` · `GIMP` · `github-copilot` · `herdr` ·
`jocalsend` · `neofetch` · `qBittorrent` · `simple-scan` · `superfile` ·
`visidata` · `weechat` · `youtube-tui` · `zoom`

Deleted along with the matching `~/.local/share` data dirs for the same dead
programs (`crush`, `felix`, `superfile`, `weechat`, `youtube-tui`, `epiphany`,
`jocalsend`). 42 paths, 88 MB freed. Archived first to
`~/backup/orphan-configs-2026-09-09.tar.zst` (28 MB).

### Four that looked dead and are not

An earlier pass of this audit listed these as orphans. They are not — checking
alternate binary names and grepping every `.nix` file caught them:

- **`goose`** — `goose-cli` is declared in `sony_ai/default.nix`; the binary is
  live at `/etc/profiles/per-user/dani/bin/goose`.
- **`opencode`** — declared in `non_home_manager_config/ollama.nix`
  `systemPackages`, live in `/run/current-system/sw/bin`.
- **`evolution`** — `services.gnome.evolution-data-server.enable = true` backs
  gnome-calendar, and `~/.config/evolution/sources/system-calendar.source` is
  its live storage config. Deleting it would have wiped calendar setup.
- **`cava`** — noctalia lists `"cava"` in `templates.builtin_ids`, so it writes
  `~/.config/cava/themes/noctalia` as a colour-template target. A declared
  output, not residue. (The `cava` binary itself is not installed, so the
  template currently writes to a file nothing reads.)

`zoom-us` stays **commented out** in `home.nix` but is still run occasionally
via `nix run zoom-us` — worth re-declaring. Its config dir held only a stale
socket and an empty lockfile, no settings, so nothing was lost.

Browser config dirs with no installed browser: `BraveSoftware`,
`microsoft-edge`, `opera` and `vivaldi` were empty stubs (8 KB each) and are
gone, archived to `~/backup/orphan-browsers-2026-09-09.tar.zst`.
**`~/.config/google-chrome` (156 MB) was kept deliberately** — it holds a real
profile, so export anything worth keeping from it before the move.

---

## 8. Loose ends — REMOVED 2026-09-09

All archived into the same tarball before deletion.

- `~/.sys1og.conf` — 40 bytes, mode 600, a bare UUID, dated 2026-07-22.
  Filename is `sys1og` with a digit one, not `syslog`. Nothing referenced it.
  **In the archive if it turns out to matter.**
- `~/.config/autostart/BrinkAgentApp.desktop` — dead `/opt` path (§4). Autostart
  is now down to `audio-recorder` and `Nextcloud`.
- `~/.zshrc` (3 lines) — stale. Verified safe: `~/.zshenv` is a store symlink
  that sources `~/.config/zsh/.zshenv` and sets `ZDOTDIR`, so `~/.zshrc` was
  never being read. `zsh -i` starts clean and aliases still load.
- `~/.config/zsh/.zcompdump.fell-omen.{561065,776410,2193636}` — old per-PID
  dumps. The live `.zcompdump` was left alone.
- `~/.config/fcitx5.backup`, `~/.config/starship.toml.backup`,
  `~/.config/hypr/hyprland.lua.backup` — pre-nix backups, superseded
- `~/.config/nvim/` — `lazy-lock.json` + a `lua/` dir; danvim wraps its own
  config (`wrapRc = true`) and never read this
- `~/.vim`, `~/.viminfo`, `~/.claude.json.tmp.*` (3 orphaned temp files)

`~/firefox-profile-backup-2026-07-28/` — deleted outright on request, no safety
copy. Confirmed a genuine Firefox profile first (`bookmarkbackups`, `cert9.db`,
`addons.json`, 83 entries). The live `~/.mozilla` is untouched.

Note on sizes: `du` reported 1.5 GB but only ~500 MB came back. `/home` is
btrfs with `compress=zstd:1`, so apparent size runs well above blocks on disk —
expect the same gap when sizing anything for the move.
