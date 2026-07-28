# dani/localsend — send files over LocalSend from noctalia

A [noctalia v5](https://github.com/noctalia-dev/noctalia) Luau plugin that
stages files by **drag-and-drop** or a **picker button**, finds nearby
[LocalSend](https://localsend.org) devices itself, and sends to the one you
click — without ever opening the LocalSend app. LocalSend is the transport
(protocol v2) and the receiver on the other end; nothing else about it is
needed on this machine.

## Features

**Bar widget** — send glyph plus the staged-file count, or the live `%` while a
transfer runs (`...` while waiting for the peer to accept, `!` on failure).
Left click opens the panel; **right click opens a drop target directly**, so
"drag a file in, send it" never needs the panel.

**Panel** (760×560, floating, centered under the bar)

- **Four ways in**: `Drop files` (a drop-target window), `Pick files`,
  `Pick folder` (recurses, preserving relative paths so the receiver rebuilds
  the tree), and `Clipboard` (sent as a LocalSend text message).
- **Staged list** with per-file size and a `×` to drop one, plus `Clear`.
- **Device list** from an active discovery sweep: type icon, alias, IP, a `★`
  to pin, and `Send`. Pinned devices sort first and stay listed while offline.
- **Transfer strip**: "waiting for <device> to accept" with Cancel, then a
  per-file progress bar with speed, then the result.
- **PIN prompt inline** when a receiver answers 401, rather than a dead end.

## Why the helpers exist

noctalia's Luau API genuinely cannot do three things this needs, so each has
exactly one external tool behind it:

| Need | Why noctalia can't | Tool |
|---|---|---|
| Find devices | no UDP sockets at all; discovery is multicast | `socat` |
| Accept dropped files | drags only start from an internal `DragSource`; there is no `wl_data_device`/`text/uri-list` path, so the shell can never be a drop surface | `ripdrag` |
| Choose files | no file dialog | `zenity` |
| Stream an upload | `noctalia.http` can't stream a body or report progress | `curl` |

## Architecture

```
service.luau ── localsend.nu ── socat (discovery) ──▶ noctalia.state
   ▲  (singleton: ALL io)   └─ curl  (upload)           "devices"/"staged"
   │                                                    "transfer"/"scanning"
   │ state.set("command", {op=...})                        │ state.watch
   │                                                       ▼
panel.luau (renders, no io)                          widget.luau (badge)
```

- `plugin.toml` — manifest: entries, panel geometry, tool paths as settings.
- `service.luau` — the only entry that spawns anything. **Transfers live here,
  not in the panel**: `prepare-upload` blocks until the receiver taps Accept,
  so a panel-owned stream would die the moment you closed the panel.
- `panel.luau` — all the UI, none of the IO.
- `widget.luau` — bar badge; event-driven, no tick, no subprocesses.
- `localsend.nu` — the whole protocol: `discover`, `stage`, `send`. `send`
  prints one JSON event per line and nu's stdout is unbuffered through a pipe,
  so `noctalia.runStream` sees progress as it happens.
- `tests/` — `fake_receiver.py` (a stand-in LocalSend receiver that can also
  answer discovery) and `run_tests.sh`.

## Settings

| key | default | meaning |
|---|---|---|
| `alias` | `noctalia` | name other devices see |
| `nu_path` | `/etc/profiles/per-user/dani/bin/nu` | runs `localsend.nu` |
| `socat_path` | `…/bin/socat` | multicast discovery |
| `curl_path` | `/run/current-system/sw/bin/curl` | uploads |
| `ripdrag_path` | `…/bin/ripdrag` | drop-target window |
| `zenity_path` | `…/bin/zenity` | file/folder pickers |
| `discover_ms` | 2000 | listen window after announcing |
| `clear_after_send` | true | empty the queue after a transfer |

Paths default to profile symlinks rather than store paths so they survive
rebuilds and GC — noctalia's PATH is not your shell's.

## Install / dev loop

Declarative install is in `../default.nix`: out-of-store symlink to
`~/.local/share/noctalia/plugins/localsend` (so `.luau` edits hot-reload),
`"dani/localsend"` in `plugins.enabled`, a `localsend` widget alias in the bar,
and `socat`/`ripdrag`/`zenity` in `home.packages`.

- Edit `.luau` → hot reload. Manifest changes need
  `noctalia msg plugins disable dani/localsend && noctalia msg plugins enable dani/localsend`.
- Watch it work: `journalctl --user -u noctalia -f | grep script-runtime`
- Lint: `noctalia plugins lint ~/.local/share/noctalia/plugins/localsend`
- Drive it headlessly (the service is always running, unlike the panel):
  ```
  noctalia msg plugin dani/localsend:agent all discover ""
  noctalia msg plugin dani/localsend:agent all stage /path/to/file
  noctalia msg plugin dani/localsend:agent all send <fingerprint>
  noctalia msg plugin dani/localsend:agent all drop|clip|cancel|clear ""
  ```
- Protocol tests, no GUI needed: `./tests/run_tests.sh` (covers accept, 403
  decline, 401 + PIN retry, 409 busy, unreachable, cancel-while-waiting, and
  progress events). For a full plugin-level run, start
  `tests/fake_receiver.py --announce` and use the IPC commands above.

## Gotchas

- **Dropping a folder does nothing.** ripdrag cannot accept directories
  ([GTK #5348](https://gitlab.gnome.org/GNOME/gtk/-/issues/5348)); the button
  tooltip says so. Use `Pick folder`, which does handle them.
- `noctalia.state` is in-memory: a disable/enable cycle (not a hot reload)
  clears the staged list and the device cache. Favourites survive — they are
  in `<pluginDataDir>/favourites.json`.
- We announce ourselves to provoke replies (that IS the discovery mechanism),
  so this machine appears in other devices' LocalSend lists. It runs **no
  server**, so a device that tries to send *to* it will fail — keep the
  LocalSend app running for receiving.
- Progress granularity is ~1s because that is how often curl writes a meter
  row; short LAN transfers finish before any intermediate row exists.
- In nushell, `(...)` inside `$"..."` is evaluated — a log string containing
  `line(s)` tries to run the command `s`. Cost an hour once already.
- Runtime overrides (`~/.local/state/noctalia/settings.toml`) replace
  nix-declared arrays wholesale. `plugins.enabled` and `bar.default.*` are
  already shadowed there on this machine, so nix edits to those two keys do
  **not** apply until the shadowing entries are updated too.
- Paths are kept unresolved (`path expand --no-symlink`) so a symlinked file
  keeps its name: on NixOS `path expand` would send `/etc/hostname` as
  `m4j1ra…-etc-hostname`.
