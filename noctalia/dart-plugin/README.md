# dani/dart — DART run manager for noctalia

A [noctalia v5](https://github.com/noctalia-dev/noctalia) Luau plugin: DART
training runs in the bar, and a dropdown panel to inspect, search and manage
them. The shell-native sibling of dart.nvim (`~/Projects/sai/dart-nvim`).

## Features

**Bar widget**: the dart logo plus per-group counts (`▶` running, `🔧` building,
`⏳` queued, `🛌` suspended; empty groups hidden), per-state counts in the
tooltip, `!` on CLI errors. Click toggles the panel.

**Panel** (1200×640, floating under the bar):

- One card per run: state, id, project, creation time, priority (0 when unset,
  as DART schedules it) and tag chips. Expanding a card shows the description,
  an info line (commit, clusters, last state change) and the actions.
- Open the run page in `$BROWSER`, or copy its id, URL or commit.
- **Filter bar**: free-form `dart run filter` args (`--tag-ss expt=foo --states
  success`), kept scoped to `--username-ss`/`--limit` unless overridden. Quote
  as in a shell, but no shell runs the text: `$`, `;` and `|` are plain
  characters. A tag chip searches for its tag; an empty filter shows your
  active runs.
- **Pin** (pin button, or the right-click menu): the run moves to the top on a
  lighter card and stays there under any filter, and after it leaves the active
  set, until it is unpinned. Pins survive restarts. A pinned run that dart no
  longer returns (deleted elsewhere) shows as `gone`; deleting one from the
  panel unpins it.
- **Actions**, gated by `dart_client`'s state machine: Cancel and Delete (with
  an inline confirm, since the CLI has none), Suspend (from `running`), Resume
  (from `suspended_manual`).
- **Logs**: `dart logs` into `/tmp/dart-logs/<run-id>/`, browsed with yazi in a
  kitty window.
- **Tag editor** (pencil): click a tag to load it for `dart tag replace`, `×`
  deletes, typing into the empty input adds.

**Transition toasts** (`notify_transitions`): one per state change between two
polls, the run id above `from → to`. A run that leaves the active set is
re-queried, so its final state is reported. Clicking a toast opens the run's
page; the panel's bell button mutes them at once.

## Architecture

```
service.luau  ──  dart run filter … --detailed | slim.nu  ──▶  noctalia.state
   ▲    (singleton poller; every 2 min + on demand)      "runs"/"error"/"busy"
   │                                                        │  state.watch
   │ state.watch("command", {op="refresh"})                 ▼
panel.luau  (renders cards; runs mutations itself)      widget.luau  (badge)
```

- `plugin.toml`: entries, panel geometry, settings.
- `common.luau`: the run-page URL, the run-id guard, the refresh request, and
  the shell-style word splitter behind the filter bar and `$BROWSER`.
- `service.luau`: the only place `dart run filter` runs; publishes state,
  raises the toasts, and keeps the pinned runs' rows fresh (one extra `--id-ss`
  query per poll, only for pins the list did not return).
- `panel.luau`: all interactive UI; runs the mutations, then requests a re-poll.
- `widget.luau`: the bar badge; no CLI calls, no tick.
- `slim.nu`: cuts the ~142 KB `--detailed` JSON to the ~10 KB the UI shows,
  keeping `json.decode` inside noctalia's 25 ms callback budget.
- `assets/dart-logo.png`: 128 px logo, drawn at 18 px.

## Settings (noctalia settings UI, or `[plugin_settings."dani/dart"]`)

| key            | default                                  | meaning                          |
|----------------|------------------------------------------|----------------------------------|
| `dart_path`    | `/home/dani/Projects/sai/.venv/bin/dart` | dart CLI (works outside the FHS shell) |
| `nu_path`      | `/etc/profiles/per-user/dani/bin/nu`     | nushell for `slim.nu`            |
| `username`     | `daniel.hernandez`                       | `--username-ss` scope            |
| `limit`        | 100                                      | `--limit` for every query        |
| `poll_seconds` | 120                                      | background poll cadence          |

## Dev loop

`../default.nix` links this directory to `~/.local/share/noctalia/plugins/dart`
out of the store, enables `dani/dart` and puts the `dart` widget in the bar.

- Saving a `.luau` hot-reloads that entry (`common.luau`: every entry); watch
  `journalctl --user -u noctalia -f`. `plugin.toml` changes need `noctalia msg
  plugins disable dani/dart && noctalia msg plugins enable dani/dart`.
- Lint: `noctalia plugins lint ~/.local/share/noctalia/plugins/dart`
- Drive it: `noctalia msg panel-toggle dani/dart:panel`,
  `noctalia msg plugin dani/dart:panel all filter "--states success"`,
  `noctalia msg plugin dani/dart:panel all open <run-id>`,
  `noctalia msg plugin dani/dart:panel all pin <run-id>` (toggles),
  `noctalia msg plugin dani/dart:widget focused refresh ""`

## Gotchas

- `noctalia.state` is in memory: a plugin disable/enable (not a hot reload)
  clears the run cache, the filter and the mute. Pins are the exception: the
  service keeps them in `pinned.json` under the plugin data dir.
- The Logs button needs `logcli` on PATH (`pkgs.grafana-loki`, ../default.nix).
- `slim.nu` needs `nu` at `nu_path`: the per-user profile symlink from
  `programs.nushell` (`../../terminal/nushell.nix`), which survives rebuilds.
- Settings-GUI changes and `noctalia msg plugins enable` land in
  `~/.local/state/noctalia/settings.toml`, which overrides config.toml (arrays
  wholesale): delete the shadowing block if a nix change doesn't apply.
- `plugin_api = 30`: a noctalia without that API refuses to load the plugin.
- A clickable toast is a detached `notify-send -A default=…` waiting on the
  D-Bus reply, alive as long as its control-center history entry. Without
  `notify-send` on PATH the toasts are plain and unclickable.
