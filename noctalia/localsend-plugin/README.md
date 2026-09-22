# dani/localsend — send and receive files over LocalSend from noctalia

A [noctalia v5](https://github.com/noctalia-dev/noctalia) Luau plugin that
stages files by **drag-and-drop** or a **picker button**, finds nearby
[LocalSend](https://localsend.org) devices itself, sends to the one you
click, and **receives** what other devices send — without ever opening the
LocalSend app. LocalSend is the transport (protocol v2) and the app on the
other end; nothing else about it is needed on this machine.

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

**Receiving** — `receiver.py` listens on 53317 for as long as the service
runs. An incoming request pops the panel with sender, files and total and
**Accept / Decline** buttons (the bar badge shows `?`); devices pinned with
★ are accepted without asking. Files land in `~/Downloads` keeping the
sender's folder structure, never overwriting (`name (1).ext`), with a
progress strip and `Cancel` while they arrive and `Open folder` when done.
The header says whether receiving is on.

## Why the helpers exist

noctalia's Luau API genuinely cannot do three things this needs, so each has
exactly one external tool behind it:

| Need | Why noctalia can't | Tool |
|---|---|---|
| Find devices | no UDP sockets at all; discovery is multicast, and a peer answers with an HTTP `register` POST, so a sweep also needs a throwaway HTTP listener | `socat` |
| Accept dropped files | drags only start from an internal `DragSource`; there is no `wl_data_device`/`text/uri-list` path, so the shell can never be a drop surface | `ripdrag` |
| Choose files | no file dialog | `zenity` |
| Stream an upload | `noctalia.http` can't stream a body or report progress | `curl` |

## Architecture

```
 phone ──HTTP──▶ receiver.py ──JSON events──▶ service.luau ──state──▶ panel / widget
                    ▲  (owns 53317: info, register, uploads)   │
                    └──── <dataDir>/decisions/<session> ◀───────┘  accept | decline | cancel
                    └──── <dataDir>/registrations.log ─▶ localsend.nu discover
 service.luau ── localsend.nu ── socat (announce + legacy UDP) / curl (send, /info scan)
```

- `plugin.toml` — manifest: entries, panel geometry, tool paths as settings.
- `service.luau` — the only entry that spawns anything. **Transfers live here,
  not in the panel**: `prepare-upload` blocks until the receiver taps Accept,
  so a panel-owned stream would die the moment you closed the panel. It also
  spawns and supervises `receiver.py` (15 s watchdog; retries every ~30 s
  while the port is busy) and turns its events into the `receive` state.
- `receiver.py` — the LocalSend v2 server: `/info`, `/register` (logged for
  discovery), `/prepare-upload` (blocks on a decision file, 90 s limit),
  `/upload` (streams to `<name>.part`, then renames), `/cancel`. One JSON
  event per line on stdout, nothing else.
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
| `download_dir` | `~/Downloads` | where received files go |
| `auto_accept_pinned` | true | ★ devices skip the prompt |
| `python_path` | `…/bin/python3` | runs `receiver.py` |

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
- Protocol tests, no GUI needed: `./tests/run_tests.sh`. Sending: accept, 403
  decline, 401 + PIN retry, 409 busy, unreachable, cancel-while-waiting,
  progress events. Discovery: a peer registering over HTTP with `receiver.py`
  like current LocalSend, one replying over UDP like old builds, and the
  receiver-down subnet-scan fallback. Receiving (`receiver.py` driven by our
  own `localsend.nu send`): accept, decline, timeout, pinned auto-accept and
  `--no-auto-accept`, `(1)` collisions, empty file, `..` and bad-parent
  rejection, busy, progress, panel cancel, register log, port busy.
  `noctalia msg plugin dani/localsend:agent all accept|decline ""` answers a
  live prompt from the shell.

## Gotchas

- **Dropping a folder does nothing.** ripdrag cannot accept directories
  ([GTK #5348](https://gitlab.gnome.org/GNOME/gtk/-/issues/5348)); the button
  tooltip says so. Use `Pick folder`, which does handle them.
- `noctalia.state` is in-memory: a disable/enable cycle (not a hot reload)
  clears the staged list and the device cache. Favourites survive — they are
  in `<pluginDataDir>/favourites.json`.
- **How discovery actually works** (verified against the LocalSend core,
  2026-09-22): a device that hears our multicast announcement answers with
  `POST /api/localsend/v2/register` to our ip:port over the protocol we
  announced — and *only* that; there is no UDP reply and a peer whose register
  fails is dropped. `receiver.py` is that endpoint: it logs every register
  and a sweep reads the lines newer than itself. The UDP listener stays for
  pre-rewrite builds, and LocalSend's own legacy scan (`GET /info` on every
  host of the /24, ~2-3s) runs when the receiver is down or the sweep comes
  back empty, which also covers access points that drop multicast.
- **The desktop app and the plugin cannot both listen on 53317.** While the
  app runs, the receiver stops (`port_busy`), the panel header says
  "receiving off — port 53317 in use", and the service retries every ~30 s;
  discovery uses the subnet scan meanwhile. Close the app to get receiving
  back. Plain HTTP only: there is no certificate, so `protocol = "http"` is
  what we announce and what peers use to reach us.
- Cancel arms a 10 s watchdog: if the helper dies without a terminal event,
  the transfer is declared cancelled anyway rather than wedging `sending`.
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
