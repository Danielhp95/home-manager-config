# dani/dart — DART run manager for noctalia

A [noctalia v5](https://github.com/noctalia-dev/noctalia) Luau plugin that puts
DART training runs in the bar: the dart logo with a running-run count, and a
dropdown panel to inspect, search, and manage runs — a shell-native sibling of
[dart.nvim](../../..//Projects/sai/dart-nvim).

## Features

**Bar widget** — dart logo + count of `running` runs; per-state counts in the
tooltip; `!` on CLI errors. Click toggles the panel.

**Panel** (1200×640, floating, centered under the bar)

- One card per run: state dot + colored state pill, run id, project chip,
  creation time, tag chips. Cards expand (chevron) to show the description,
  an info line (copyable git commit, clusters, last state change), and actions.
- Run id click → run page in `$BROWSER`; copy buttons for id and commit.
- **Filter bar**: free-form `dart run filter` args (e.g.
  `--tag-ss expt=foo --states success`). Applied args stay scoped to
  `--username-ss <you>` and `--limit <n>` unless you override them (the CLI
  keeps the last occurrence of a repeated option). Clicking a **tag chip**
  searches `--tag-ss '<tag>'`. Empty filter → default query (your active runs).
- **Actions**, gated by `dart_client`'s state machine: Cancel (two-step
  confirm), Suspend (only from `running`), Resume (only from
  `suspended_manual`), Delete (two-step confirm). The CLI has no confirmation
  flag, so the panel owns the confirm step.
- **Logs**: downloads pod logs (`dart logs`) to `/tmp/dart-logs/<run-id>/` and
  opens yazi on them in a kitty window.
- **Tag editor** (pencil button): chips become `[tag][×]` pairs — click the
  tag to load it into the input (Enter runs `dart tag replace`), `×` deletes,
  typing into the empty input adds.

## Architecture

```
service.luau  ──  dart run filter … --detailed | slim.nu  ──▶  noctalia.state
   ▲    (singleton poller; every 2 min + on demand)      "runs"/"error"/"busy"
   │                                                        │  state.watch
   │ state.watch("command", {op="refresh"})                 ▼
panel.luau  (renders cards; runs mutations itself)      widget.luau  (badge)
```

- `plugin.toml` — manifest: entries, panel geometry, user settings.
- `service.luau` — the only place `dart run filter` runs. Handles the
  custom-filter query, queues refreshes requested mid-poll, publishes state.
- `panel.luau` — all interactive UI. Mutations (`dart run cancel/…`,
  `dart tag …`) run here, toast their result, then request a re-poll.
- `widget.luau` — bar badge; purely event-driven, no CLI calls, no tick.
- `slim.nu` — projects the ~142 KB `--detailed` JSON down to the fields the
  UI shows (~10 KB), keeping Lua `json.decode` well inside noctalia's 25 ms
  script-callback budget.
- `assets/dart-logo.png` — 128 px logo (bar renders it at 18 px, 3× loaded).

## Settings (noctalia settings UI, or `[plugin_settings."dani/dart"]`)

| key            | default                                  | meaning                          |
|----------------|------------------------------------------|----------------------------------|
| `dart_path`    | `/home/dani/Projects/sai/.venv/bin/dart` | dart CLI (works outside the FHS shell) |
| `nu_path`      | `/etc/profiles/per-user/dani/bin/nu`     | nushell for `slim.nu`            |
| `username`     | `daniel.hernandez`                       | `--username-ss` scope            |
| `limit`        | 30                                       | `--limit` for every query        |
| `poll_seconds` | 120                                      | background poll cadence          |

## Install / dev loop

Declarative install is in `../default.nix`: the plugin dir is linked to
`~/.local/share/noctalia/plugins/dart` (out-of-store symlink, so edits here
hot-reload the running shell), `plugins.enabled = ["dani/dart"]`, and the
`dart` widget alias sits in `bar.default.end`.

- Edit any `.luau` → noctalia hot-reloads that entry (watch `journalctl
  --user -u noctalia -f` for errors). Manifest changes need
  `noctalia msg plugins disable dani/dart && noctalia msg plugins enable dani/dart`.
- Lint: `noctalia plugins lint ~/.local/share/noctalia/plugins/dart`
- Drive it: `noctalia msg panel-toggle dani/dart:panel`,
  `noctalia msg plugin dani/dart:panel all filter "--states success"`,
  `noctalia msg plugin dani/dart:panel all open <run-id>`,
  `noctalia msg plugin dani/dart:widget focused refresh ""`

## Gotchas

- `noctalia.state` is in-memory: a plugin disable/enable (not a hot reload)
  clears the run cache and any active filter.
- The Logs button needs `logcli` (`dart logs` shells out to it).
  `pkgs.grafana-loki` is in home.packages; until a rebuild lands, the button
  falls back to a pinned store path (`LOGCLI_DIR` in panel.luau) — if that
  path gets GC'd the kitty window shows the missing-binary error.
- `slim.nu` needs `nu` on disk at `nu_path`, which comes from
  `programs.nushell` in `../../terminal/nushell.nix` — the default points at
  the per-user profile symlink rather than a store path so rebuilds and GC
  don't break it. Disabling that module breaks polling; repoint `nu_path`.
- Runtime overrides (`~/.local/state/noctalia/settings.toml`, written by the
  GUI and `noctalia msg plugins enable`) merge OVER the nix-managed
  config.toml and replace arrays wholesale — if nix edits to `plugins.enabled`
  or `bar.default.end` stop applying, delete the shadowing block there.
- Tag values containing a single quote can't be safely shell-quoted; those
  operations are rejected with a toast rather than risking mangled commands.
