# localsend-plugin receive side: design

Date: 2026-09-22 · Status: design approved in chat, awaiting spec review

The `dani/localsend` noctalia plugin becomes a full LocalSend v2 endpoint:
other devices can send files to this laptop without the LocalSend desktop app
being open. Today the plugin is sender-only; the only server it ever runs is
a throwaway `register` responder for the ~2s of a discovery sweep, so a phone
that picks this machine gets "connection refused".

## 1. Decisions (from the brainstorming Q&A)

| Topic | Decision |
|---|---|
| Accept flow | Prompt on every incoming request, except devices pinned (★) in the panel, which are accepted automatically |
| Save location | `~/Downloads`, configurable through a `download_dir` plugin setting |
| Desktop app | Stays installed. While it runs it owns port 53317 and the plugin's receiver steps aside, retrying until the port frees up |
| Transport | Plain HTTP on 53317, which is what the plugin already announces. TLS is a follow-up, not part of this work |
| Runtime | A persistent Python receiver (`receiver.py`), evolved from `tests/fake_receiver.py`, spawned and supervised by the Luau service |
| Identity | The existing random 64-hex fingerprint, alias from the `alias` setting (`noctalia`). Same identity for sending and receiving |
| Out of scope | Receiver-side PIN, TLS, the download API (`download` stays `false`), accepting a subset of the offered files |

## 2. Background: what a sender does

Protocol v2, as implemented by current LocalSend (Rust core):

1. `POST /api/localsend/v2/prepare-upload` with `{info, files: {id: {id, fileName, size, fileType, preview?}}}`. The receiver blocks until the user decides, then answers `200 {sessionId, files: {id: token}}`, `403` (declined), `409` (busy with another session) or `401` (PIN, not used here).
2. One `POST /api/localsend/v2/upload?sessionId=&fileId=&token=` per file with the raw bytes as body and a `Content-Length`.
3. Optionally `POST /api/localsend/v2/cancel?sessionId=`.

Discovery from the sender's side: it multicasts an announcement, and every device that hears it answers with `POST /api/localsend/v2/register` to `<announced protocol>://<source ip>:<announced port>`. Its "legacy scan" asks every host of the subnet `GET /api/localsend/v2/info`.

## 3. Components

```
 phone ──HTTP──▶ receiver.py ──stdout JSON events──▶ service.luau ──state──▶ panel / widget
                    ▲                                   │
                    └──── <dataDir>/decisions/<session> ◀┘   (accept | decline)
                    └──── <dataDir>/registrations.log ─▶ localsend.nu discover
```

### 3.1 `receiver.py` (new)

A single-file `ThreadingHTTPServer` on `0.0.0.0:53317`, plain HTTP. Started as

```
python3 receiver.py --port 53317 --alias <alias> --fingerprint <fp> \
    --download-dir <dir> --data-dir <pluginDataDir> --auto-accept <favourites.json>
```

Endpoints (all under `/api/localsend/v2/`):

| Route | Behaviour |
|---|---|
| `GET info` | Our device info JSON (alias, version `2.1`, deviceModel `noctalia`, deviceType `desktop`, fingerprint, port, protocol `http`, download `false`) |
| `POST register` | Same JSON as the reply; appends `<epoch_ms> <peer ip> <body>` to `registrations.log` |
| `POST prepare-upload` | See §4 |
| `POST upload` | See §4 |
| `POST cancel` | Marks the session cancelled; a running upload for it stops and the partial file is deleted |
| anything else | `404` |

The receiver prints one JSON object per line on stdout; nothing else is ever
printed there. Diagnostics go to stderr.

| Event | Fields | When |
|---|---|---|
| `listening` | `port` | The socket is bound |
| `port_busy` | `port` | Bind failed with `EADDRINUSE`; the process exits `2` right after |
| `request` | `session`, `sender {alias, ip, fingerprint, deviceType, deviceModel}`, `files [{id, name, size, type, preview?}]`, `total`, `auto` (bool) | A `prepare-upload` arrived; `auto` is true when the sender is pinned and was accepted without asking |
| `accepted` / `declined` / `timeout` | `session` | Decision applied (timeout = no decision within 90s, sender gets `403`) |
| `file` | `session`, `index`, `total`, `name`, `size`, `path` | An upload started; `path` is the final on-disk path |
| `progress` | `session`, `index`, `name`, `percent`, `speed` | At most every 250ms while bytes arrive |
| `file_done` | `session`, `index`, `name`, `path` | File fully written |
| `done` | `session`, `received`, `paths` | Every file of the session is written, or the sender stopped sending after the last one it had a token for |
| `cancelled` | `session`, `index?` | Sender sent `cancel`, or the connection dropped mid-upload |
| `error` | `session?`, `message` | Anything else; the receiver keeps running |

### 3.2 `service.luau` (changed)

- Spawns the receiver at startup with `runStream` (argv assembled with `shq`, same as `send`) and dispatches events into a new `receive` state (§5).
- **Decisions**: `{op="accept", session}` / `{op="decline", session}` commands from the panel write `<dataDir>/decisions/<session>` with `accept` or `decline`. Pinned senders never reach the panel: the receiver gets the favourites file path and accepts them itself, so the decision is not racy with a service reload.
- **Supervision**: `update()` on a 15s `setUpdateInterval`. The receiver writes `<dataDir>/receiver.pid`; the tick runs `kill -0 <pid>` through `runAsync`. Dead and last event was `port_busy` → retry every 30s (2 ticks). Dead otherwise → respawn immediately and log. `onExit` removes the pid file and the receiver is killed by the runtime (streams die with it).
- On `request` (not `auto`) it opens the panel (`noctalia.togglePanel` only if not already open, tracked by a `panelOpen` state the panel publishes from `onOpen`/`onClose`) and notifies "X wants to send N files (size)". On `auto` it notifies "Receiving N files from X".
- On `done`: notify "Received N files from X" — for a single text message (one file with a `preview`) the notification body is the preview. On `declined`/`timeout`/`cancelled`/`error`: notify accordingly.
- Keeps the existing send side untouched.

### 3.3 `panel.luau` (changed)

- **Header status**: receiving on ("receiving as *alias*") / off with reason ("receiving off — port 53317 in use, LocalSend app open?").
- **Incoming strip** (above the transfer strip, when `receive.state == "waiting"`): sender glyph + alias + ip, file rows (name, size), total, `Accept` (primary) and `Decline` (ghost). Buttons are disabled once a decision was sent, until the receiver confirms.
- **Receiving strip** (`receive.state == "receiving"`): current file `(i/n)`, speed, percent, progress bar, `Cancel` (writes the decision file `cancel`, which the receiver treats like a sender cancel).
- **Result strip** (`done` / `declined` / `cancelled` / `error`): message + `Dismiss` (`{op="dismiss_receive"}`), plus `Open folder` on `done` (`xdg-open <download_dir>` via `runAsync`).
- `onOpen` / `onClose` publish `panelOpen` so the service knows whether to open it.

### 3.4 `widget.luau` (changed)

Receive takes precedence over send in the badge when both are active (rare):

| `receive.state` | Badge |
|---|---|
| `waiting` | glyph `download`, text `?`, tertiary; tooltip "X wants to send N files" |
| `receiving` | glyph `download`, text `<percent>%`, primary; tooltip rows from / file / speed |
| `error` | glyph `download`, `!`, error colour, until dismissed |
| otherwise | existing send badge |

### 3.5 `localsend.nu discover` (changed)

The receiver now owns 53317, so the sweep no longer starts its own register
responder. New flow:

1. Note `start = now (epoch ms)`.
2. Start the legacy UDP listener (unchanged, for pre-rewrite builds).
3. Announce twice (unchanged).
4. Sleep the window.
5. Read `registrations.log` lines with `ts >= start` → devices (ip from the line, fields from the body).
6. If nothing was found, or the receiver is not running (`--registrations` file missing or no `listening` state; the service passes `--receiver-up true|false`), run the `/info` subnet scan (unchanged).
7. Merge, dedupe by fingerprint, print.

The UDP handler script file stays; the HTTP handler constant is removed. Tests
that relied on the sweep's own responder start `receiver.py` on 53317 instead.

### 3.6 `plugin.toml` / `default.nix` / README

- New settings: `download_dir` (string, default `~/Downloads`, `~` expanded by the service), `auto_accept_pinned` (bool, default true), `python_path` (advanced, default `/etc/profiles/per-user/dani/bin/python3`).
- `default.nix`: nothing new — python3 is already on the user profile; 53317 TCP is already open in `network.nix`.
- README: architecture diagram and the "receiving is the app's job" gotcha rewritten; the app-open behaviour documented.

## 4. Receive flow in detail

**prepare-upload**

1. Parse `info` (sender) and `files`. Reject malformed JSON with `400`.
2. If a session is active (accepted and not finished) → `409`.
3. Validate every `fileName`: reject with `400` if it is absolute, contains `..` as a path component, or is empty after trimming. Directory components are kept (folder sends).
4. Emit `request`. If the sender's fingerprint is in the favourites file and `auto_accept_pinned` → decision `accept`, `auto = true`.
5. Otherwise wait for `<dataDir>/decisions/<session>` (poll 200ms, 90s limit). Missing after 90s → `timeout` event, `403`.
6. `accept` → create the session with one random 32-hex token per file, emit `accepted`, reply `200 {sessionId, files: {id: token}}`. `decline` → `declined`, `403`.

**upload**

1. Look up session/file/token; mismatch → `403`; file already received → `409`.
2. Resolve the target: `<download_dir>/<fileName>`, creating parent directories. If the target exists, use `name (1).ext`, `name (2).ext`, … (the suffix goes before the extension).
3. Write to `<target>.part`, reading `Content-Length` bytes in 256 KiB chunks, emitting `progress` (percent from bytes, speed from a 1s window). Body shorter than `Content-Length` (connection dropped) → delete the `.part`, emit `cancelled`, close the session.
4. Rename `.part` → target, emit `file_done`, reply `200`.
5. When every file that has a token is done → emit `done`, close the session.

**cancel** (from sender): stop and delete any running `.part`, emit `cancelled`, close the session. A `cancel` decision file from the panel does the same and answers the in-flight upload with `500`.

**Decisions directory** is wiped at receiver start (stale decisions must never accept a new session).

## 5. State published by the service

`noctalia.state "receive"`:

```
{ state:   "off" | "idle" | "waiting" | "receiving" | "done" | "declined"
           | "cancelled" | "error",
  reason:  string?      -- for "off": "port 53317 in use (LocalSend app open?)" | "receiver crashed"
  session: string?,
  sender:  {alias, ip, fingerprint, deviceType}?,
  files:   [{id, name, size, type, preview?}]?,
  total:   number?,     -- bytes
  index, name, percent, speed,   -- while receiving
  received: number?, paths: [string]?, message: string?  -- results
}
```

`"panelOpen"`: boolean, published by the panel.

## 6. Error handling

| Failure | Behaviour |
|---|---|
| Port 53317 busy at start | `port_busy` → state `off` with reason; retry every 30s; panel header shows it |
| Receiver crashes | Watchdog respawns within 15s; state `off`/"receiver crashed" until `listening` |
| Sender vanishes while we wait for a decision | The blocked `prepare-upload` handler notices the closed socket when it replies; the session is dropped, strip cleared |
| Sender vanishes mid-upload | Short body → `.part` deleted, `cancelled` |
| Disk full / unwritable dir | `error` with the OS message, `500` to the sender, `.part` deleted |
| Bad file names (`..`, absolute) | `400`, `error` event naming the file |
| Two senders at once | Second gets `409` (LocalSend shows "busy") |
| Service reload mid-transfer | The receiver dies with the runtime; the sender sees a dropped connection and reports failure. Acceptable: reloads are developer actions |

## 7. Testing

`tests/run_tests.sh` gains a receive section that starts `receiver.py` on a
free port with a temp download dir and drives it with `localsend.nu send`
(our own sender), plus a decision helper that writes the decision file:

- accept: two files, one nested, bytes match, `done` with both paths
- decline: sender gets `403`, `declined` event
- auto-accept: sender fingerprint in a favourites file → `auto: true`, no decision needed
- timeout: no decision → `403` after the (test-shortened) limit
- collision: sending `a.txt` twice yields `a.txt` and `a (1).txt`
- traversal: `../x` in a name → `400`
- busy: second prepare-upload during a session → `409`
- progress: throttled upload emits ≥2 `progress` events
- cancel from sender: `.part` removed, `cancelled`
- port busy: a second receiver on the same port emits `port_busy` and exits `2`
- discovery: `receiver.py` on 53317 + a `register` POST during a sweep → device listed via `registrations.log` (replaces the sweep-responder test)

Existing send/discovery cases keep passing. `noctalia plugins lint` stays
clean.

## 8. Files touched

| File | Change |
|---|---|
| `noctalia/localsend-plugin/receiver.py` | new |
| `noctalia/localsend-plugin/service.luau` | spawn/supervise receiver, decisions, `receive` state, notifications |
| `noctalia/localsend-plugin/panel.luau` | incoming / receiving / result strips, header status, `panelOpen` |
| `noctalia/localsend-plugin/widget.luau` | receive badge |
| `noctalia/localsend-plugin/localsend.nu` | discover reads `registrations.log`; responder removed |
| `noctalia/localsend-plugin/plugin.toml`, `translations/en.json` | new settings |
| `noctalia/localsend-plugin/tests/run_tests.sh`, `tests/fake_receiver.py` | receive cases; fake receiver keeps serving the send tests |
| `noctalia/localsend-plugin/README.md` | architecture, gotchas |
