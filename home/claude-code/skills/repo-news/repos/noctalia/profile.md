---
slug: noctalia
upstream: noctalia-dev/noctalia
host: github
branch: main
aliases: [noctalia-shell, noctalia-dev]
---

# Noctalia

The Wayland desktop shell: bar, panels, notifications, lockscreen, launcher, greeter.
The user configures it from `~/nix_config` through its Home Manager module and writes a
Luau plugin for it.

## News sources

Noctalia has no changelog file. Its user-facing news is the **GitHub release notes**
(sections: New Features, Compatibility Notes, Notable Fixes); unreleased work shows only
in the commit log. Keep `last_release` in `state.json`.

1. Releases, newest first — read the full body of each one inside the window:
   `gh api 'repos/noctalia-dev/noctalia/releases?per_page=10'`
   The **Compatibility Notes** section is the one that breaks configs; never skim it.
2. The compare (`<last_commit>...main`). Prioritize `feat`, `feat!` and `fix` subjects,
   and changes to the files that define the surface a config can touch:
   - `example.toml` — the whole config schema with defaults; a diff of it is the most
     precise list of new, renamed and removed keys.
   - `docs/plugin-api.json` — one entry per plugin API level and what it introduced.
   - `docs/user/**` — user docs (bar, ipc, plugins, theming, lockscreen, …).
   - `nix/home-module.nix`, `nix/nixos-module.nix`, `nix/package.nix` — the
     `programs.noctalia` and greeter module options and the build.
   - `src/cli/schema_msg.h` — the `noctalia msg` command table.
   - `assets/translations/en.json` — string keys (the config patches some).

If the compare is too large or rate-limited, fall back to the release notes plus a diff
of `example.toml` between the two revs, and note the limitation in the report.

## Local setup

- `home/noctalia/default.nix` — `programs.noctalia.settings` (rendered to `config.toml`), the
  enabled plugins, the bar layout, widgets, idle and lockscreen behaviour, and the
  patched asset bundle passed through `NOCTALIA_ASSETS_DIR`.
- `home/noctalia/material.nix` — maps the repo palette to Noctalia's palette JSON roles; also
  used by the greeter.
- `home/noctalia/dart-plugin/` — a local Luau plugin (`plugin.toml` declares `plugin_api`).
- `home/noctalia/noctalia.d.luau` — hand-written type definitions for the plugin API; its
  header records the Noctalia commit and API level it was last checked against.
- `nixos/greeter.nix` — the greeter (display manager).
- `home/hyprland/hyprland.lua` — binds that call `noctalia msg …`, and layer rules that match
  Noctalia's layer namespaces.

Find the rest rather than trusting this list: `grep -rn -i noctalia ~/nix_config
--include='*.nix' --include='*.lua' --include='*.luau' --include='*.toml'` (skip
`danvim/` and `flake.lock`).

Also read `~/.local/state/noctalia/settings.toml`. Changes made in the settings GUI land
there and **override** the Nix config (arrays wholesale), so it is part of the effective
config: a key the user "has not set" in Nix may be set there.

A change is **relevant** if it: adds a native option for something the config builds by
hand (a script, a layer rule, a patched asset, a plugin), renames or removes a key, IPC
command, widget type or palette role the config uses, changes a default the config
relies on or overrides, raises or drops a plugin API level the DART plugin or the type
definitions depend on, or fixes a bug a comment in the config works around.

## Pin

Three revisions matter and they are often all different:

```bash
cd ~/nix_config
# what the next rebuild will build
python3 -c "
import json,datetime
n=json.load(open('flake.lock'))['nodes']['noctalia']['locked']
print('locked ', n['rev'], datetime.datetime.fromtimestamp(n['lastModified'], datetime.UTC).isoformat())"
# what is running right now (lags the lock until the user switches)
noctalia --version
# the locked source tree itself, in the store: grep it instead of fetching files
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.noctalia.outPath'
```

The input tracks `main`, not releases, so the lock can already contain unreleased work.
Report whether the running version is older than the lock.

## Fragile points

Where the setup reaches past Noctalia's documented surface; these break without a
Compatibility Note, and an upstream feature that makes one unnecessary is a high-value
[ADOPT]:
- the `en.json` keys patched into the asset bundle (the build fails if one is renamed);
- `noctalia.d.luau`, written from the C++ bindings — compare its "Last checked against"
  commit and API level with `docs/plugin-api.json`;
- layer namespaces and `noctalia msg` command names used in `hyprland.lua`;
- plugin entry ids and widget types (`author/plugin:entry`) in the bar and the binds;
- every comment in the config that explains a workaround ("can't", "never", "must",
  "otherwise") — each names a behaviour upstream may have changed.

## Verifying at the pin

The locked source is already in the Nix store (the `outPath` above), so check it
directly:
- **A config key** — find it in `<outPath>/example.toml` and read the line: its table,
  type, default and comment. Release notes abbreviate; a key announced as
  `compositor_blur` may live under `[bar.<name>]`, a per-monitor table, or a widget.
- **An IPC command** — `<outPath>/src/cli/schema_msg.h` (and `noctalia msg --help` for
  the *running* version; if the two differ, a bind needs the switch before it works).
- **A module option** — `<outPath>/nix/home-module.nix` / `nixos-module.nix`.
- **A plugin API feature** — `<outPath>/docs/plugin-api.json` for its level, and the
  supported range the shell accepts (grep `src/` for where `plugin_api` is validated).
- **A fix for a worked-around bug** — find the fixing commit and confirm it is not in
  the list `compare/<locked_rev>...main` returns.

Options are often reshaped between the first commit and the release (renamed, moved to
another table, given a different type), and an edit written from the blurb alone
produces a key Noctalia silently ignores.

## Report specifics

- Header gets two extra lines: `**Releases in window:**` and
  `**Locked:** <sha> (<date>, <N> behind main) · **Running:** <version (sha)>`.
- Relevance tags: [ADOPT] native option worth enabling · [REPLACES <workaround>] ·
  [BREAKING] · [NEUTRAL].
- Impact section title: "Impact on the Noctalia config"; rows keyed by area, e.g.
  `home/noctalia/default.nix` (bar). Snippets are `nix`.
- Add a `### Plugin API` subsection under Impact: the supported range at the locked
  rev, the level `dart-plugin/plugin.toml` declares, and anything new since the level
  `noctalia.d.luau` was last checked against.
- "Blocked on a pin bump" items say: re-check after `nix flake update noctalia`.
- The enabled community plugins live in other repos (`noctalia msg plugins source
  list`). They are out of scope unless a Noctalia change in the window breaks one of
  them — then say which plugin and why.

## Applying

- A pin bump is `nix flake update noctalia` in `~/nix_config` — ask before running it.
- **Visible changes need the user's eyes.** Anything that changes how the bar, panels,
  notifications or lockscreen look or behave is a matter of taste, and a change that
  reads well in a release note can look wrong on this screen. Say what will look
  different and treat the edit as provisional until the user has seen it running.
- Match the surrounding style: the Nix files carry a comment on almost every setting
  that says *why* it is set. A new or changed setting gets one too, and a removed
  workaround takes its comment with it.
- Removing a workaround means removing every part of it — e.g. a layer rule in
  `hyprland.lua` *and* the comment in `home/noctalia/default.nix` that points at it.
- If a change touches the plugin API, update the "Last checked against" header of
  `home/noctalia/noctalia.d.luau` only for what was actually re-checked.

How an edit goes live:
- **Nix settings** (`home/noctalia/default.nix`, `material.nix`, the greeter) need a rebuild
  and switch; the switch restarts `noctalia.service`. Building (`nh os build`) checks
  that the config evaluates; switching needs the user (sudo).
- **The DART plugin** is linked out of the store, so edits to `noctalia/dart-plugin/`
  hot-reload in the running shell with no rebuild.
- **`hyprland.lua`** edits also need the switch.
- If a setting does not take effect after the switch, look in
  `~/.local/state/noctalia/settings.toml` first: a value saved there by the GUI shadows
  the Nix one, and for a list (the bar lanes, `plugins.enabled`) it replaces it whole.
- A plugin that was just enabled needs `noctalia msg plugins enable <id>` and a restart
  of `noctalia.service` before its widget resolves; community plugin sources update
  with `noctalia msg plugins update`, not a hand `git fetch`.
