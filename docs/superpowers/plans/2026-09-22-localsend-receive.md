# localsend-plugin receive side — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `dani/localsend` noctalia plugin receive files (LocalSend v2) as well as send them, with an accept prompt in the panel, pinned devices auto-accepted, and files saved under `~/Downloads`.

**Architecture:** A persistent Python HTTP receiver (`receiver.py`) owns port 53317 and prints one JSON event per line; the Luau service spawns and supervises it, turns events into a `receive` state that the panel and bar widget render, and answers the receiver through decision files. Discovery stops running its own throwaway responder and reads the receiver's registration log instead.

**Tech Stack:** Python 3.14 stdlib (`http.server`), Luau (noctalia plugin API 28+), nushell 0.115, bash tests driven by the plugin's own `localsend.nu send`.

**Spec:** `docs/superpowers/specs/2026-09-22-localsend-receive-design.md`

## Global Constraints

- Plain HTTP on port `53317`; protocol version string `2.1`; `deviceModel` `noctalia`, `deviceType` `desktop`, `download` `false`.
- The receiver prints **only** JSON events on stdout (one per line, flushed); everything else goes to stderr.
- Decision files live in `<pluginDataDir>/decisions/<sessionId>` and contain exactly `accept`, `decline` or `cancel`; the directory is wiped at receiver start.
- File names from senders keep their relative directories, and are rejected (`400`) if absolute or containing a `..` component.
- Existing files are never overwritten: `name (1).ext`, `name (2).ext`, …
- Decision timeout 90 s (flag `--decision-timeout`, tests use a short value).
- Tool paths come from plugin settings (profile symlinks, never store paths): `python_path` default `/etc/profiles/per-user/dani/bin/python3`.
- Never add AI attribution to commits.
- Hot reload: `.luau` edits reload live; `plugin.toml` changes need `noctalia msg plugins disable dani/localsend && noctalia msg plugins enable dani/localsend`.

## Review Focus

1. A sender that offers a file name with a directory component that already exists as a *file* (`a.txt/b.txt`) — expected: `500`/`error` event naming the file, no crash, session closed. Test added to Task 1 (`test traversal and bad parent`).
2. `Content-Length: 0` upload (empty file) — expected: an empty file is created and `file_done` emitted. Test added to Task 1.
3. A pinned sender while `auto_accept_pinned = false` — expected: prompt like anyone else. Test added to Task 1 (`--no-auto-accept`).
4. Two `request`s in a row where the panel dismissed the first: the strip must show the second, not stay on the stale result. Covered by the service's `request` handler replacing `receive` wholesale (Task 3), checked manually.
5. The receiver's `registrations.log` growing forever — expected: truncated at each receiver start. Test added to Task 1 (`registrations.log truncated`).

---

### Task 1: `receiver.py` with protocol tests

**Files:**
- Create: `noctalia/localsend-plugin/receiver.py`
- Modify: `noctalia/localsend-plugin/tests/run_tests.sh` (append a receive section before the final summary)

**Interfaces:**
- Consumes: nothing new; the tests use `localsend.nu send` (existing) as the sender.
- Produces: the CLI `python3 receiver.py --port P --alias A --fingerprint F --download-dir D --data-dir X --favourites FILE [--no-auto-accept] [--decision-timeout S]`; the stdout event stream defined in spec §3.1; files `<data-dir>/receiver.pid`, `<data-dir>/registrations.log`, `<data-dir>/decisions/`.

- [ ] **Step 1: Write the failing tests** — append to `tests/run_tests.sh` right before the `echo` / `ALL TESTS PASSED` block:

```bash
# ───────────────────────────────────────────────── receive (receiver.py) ───
# receiver.py is driven by our own sender. A decision is a file the panel
# would write; here the test writes it once the receiver has emitted the
# `request` event (which carries the session id).
RPORT=8398
RDATA="$WORK/rdata"; RDL="$WORK/downloads"
RECV_PID=""

start_receiver_py() { # extra args...
  [ -n "$RECV_PID" ] && kill "$RECV_PID" 2>/dev/null
  rm -rf "$RDATA" "$RDL"; mkdir -p "$RDATA" "$RDL"
  python3 "$HERE/../receiver.py" --port "$RPORT" --alias fake-laptop --fingerprint RECVFINGERPRINT \
    --download-dir "$RDL" --data-dir "$RDATA" --favourites "$WORK/favs.json" --decision-timeout 3 "$@" \
    > "$WORK/recv_events.jsonl" 2> "$WORK/recv.err" &
  RECV_PID=$!
  for _ in $(seq 1 40); do
    grep -q '"event": "listening"' "$WORK/recv_events.jsonl" 2>/dev/null && return 0
    sleep 0.1
  done
  echo "receiver.py failed to start"; cat "$WORK/recv.err"; return 1
}

decide() { # accept|decline|cancel -> waits for the request event, writes the decision
  for _ in $(seq 1 50); do
    sid=$(grep -o '"session": "[0-9a-f]*"' "$WORK/recv_events.jsonl" 2>/dev/null | tail -1 | grep -o '[0-9a-f]\{32\}')
    [ -n "$sid" ] && break
    sleep 0.1
  done
  echo "$1" > "$RDATA/decisions/$sid"
}

rjob() { # files-json -> job file targeting receiver.py
  cat > "$WORK/rjob.json" <<EOF
{"device": {"ip": "127.0.0.1", "port": $RPORT, "protocol": "http", "alias": "fake-laptop"},
 "pin": null, "alias": "noctalia-test", "fingerprint": "SENDERFINGERPRINT",
 "files": $1}
EOF
  echo "$WORK/rjob.json"
}
echo '[]' > "$WORK/favs.json"

echo "== receive: accept two files, one nested =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "request event"   '"event": "request"'   "$WORK/recv_events.jsonl"
check "not auto"        '"auto": false'         "$WORK/recv_events.jsonl"
check "accepted event"  '"event": "accepted"'  "$WORK/recv_events.jsonl"
check "done received=2" '"received": 2'        "$WORK/recv_events.jsonl"
check "sender done"     '"event":"done","sent":2' "$WORK/out.jsonl"
if cmp -s "$WORK/a.txt" "$RDL/a.txt" && cmp -s "$WORK/b.bin" "$RDL/sub/b.bin"; then
  echo "  PASS  received bytes match (nested path preserved)"
else
  echo "  FAIL  received bytes differ"; ls -R "$RDL"; FAILED=1
fi
[ -z "$(ls "$RDL" | grep '\.part$')" ] && echo "  PASS  no .part left behind" || { echo "  FAIL  .part left"; FAILED=1; }

echo "== receive: decline =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide decline; wait $SEND_PID
check "declined event" '"event": "declined"' "$WORK/recv_events.jsonl"
check "sender got 403" '"message":"declined"' "$WORK/out.jsonl"

echo "== receive: no decision -> timeout =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1
check "timeout event"  '"event": "timeout"'  "$WORK/recv_events.jsonl"
check "sender got 403" '"message":"declined"' "$WORK/out.jsonl"

echo "== receive: pinned sender is auto-accepted =="
echo '[{"fingerprint": "SENDERFINGERPRINT", "alias": "noctalia-test"}]' > "$WORK/favs.json"
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1
check "auto true"   '"auto": true'          "$WORK/recv_events.jsonl"
check "sender done" '"event":"done","sent":2' "$WORK/out.jsonl"

echo "== receive: pinned sender still prompted with --no-auto-accept =="
start_receiver_py --no-auto-accept || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "auto false" '"auto": false' "$WORK/recv_events.jsonl"
echo '[]' > "$WORK/favs.json"

echo "== receive: name collision gets (1) suffix =="
start_receiver_py || exit 1
ONE="[{\"path\": \"$WORK/a.txt\", \"name\": \"a.txt\", \"size\": $(stat -c%s "$WORK/a.txt"), \"type\": \"text/plain\"}]"
for _ in 1 2; do
  $NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out.jsonl" 2>&1 &
  SEND_PID=$!; decide accept; wait $SEND_PID; : > "$WORK/recv_events.jsonl"
done
[ -f "$RDL/a.txt" ] && [ -f "$RDL/a (1).txt" ] && echo "  PASS  a.txt and a (1).txt" || { echo "  FAIL  collision"; ls "$RDL"; FAILED=1; }

echo "== receive: empty file =="
start_receiver_py || exit 1
: > "$WORK/empty.bin"
EMPTY="[{\"path\": \"$WORK/empty.bin\", \"name\": \"empty.bin\", \"size\": 0, \"type\": \"application/octet-stream\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$EMPTY")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
[ -f "$RDL/empty.bin" ] && [ ! -s "$RDL/empty.bin" ] && echo "  PASS  empty file created" || { echo "  FAIL  empty file"; FAILED=1; }
check "file_done for empty" '"event": "file_done"' "$WORK/recv_events.jsonl"

echo "== receive: traversal and bad parent rejected =="
start_receiver_py || exit 1
BAD="[{\"path\": \"$WORK/a.txt\", \"name\": \"../escape.txt\", \"size\": 16, \"type\": \"text/plain\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BAD")" > "$WORK/out.jsonl" 2>&1
check "sender got 400"     '"code":400'          "$WORK/out.jsonl"
check "error names file"   'rejected file name'  "$WORK/recv_events.jsonl"
[ ! -e "$WORK/escape.txt" ] && echo "  PASS  nothing written outside" || { echo "  FAIL  escaped"; FAILED=1; }
touch "$RDL/blocker"
BADP="[{\"path\": \"$WORK/a.txt\", \"name\": \"blocker/inner.txt\", \"size\": 16, \"type\": \"text/plain\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BADP")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
check "error event on bad parent" '"event": "error"' "$WORK/recv_events.jsonl"
check "sender got 500" '"code":500' "$WORK/out.jsonl"

echo "== receive: busy while a session is open =="
start_receiver_py || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$FILES")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; sleep 0.5
$NU --no-config-file "$SCRIPT" send "$(rjob "$ONE")" > "$WORK/out2.jsonl" 2>&1
check "second sender busy" 'busy with another transfer' "$WORK/out2.jsonl"
decide accept; wait $SEND_PID

# Localhost moves 40 MB in well under the 250 ms progress interval, so the
# receiver is throttled (20 ms per 256 KiB chunk, ~3 s per file) to make
# intermediate progress and a mid-upload cancel observable at all.
echo "== receive: progress events on a big file =="
start_receiver_py --throttle 0.02 || exit 1
head -c 40000000 /dev/urandom > "$WORK/big.bin"
BIG="[{\"path\": \"$WORK/big.bin\", \"name\": \"big.bin\", \"size\": 40000000, \"type\": \"application/octet-stream\"}]"
$NU --no-config-file "$SCRIPT" send "$(rjob "$BIG")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept; wait $SEND_PID
N=$(grep -c '"event": "progress"' "$WORK/recv_events.jsonl")
[ "$N" -ge 1 ] && echo "  PASS  $N progress events" || { echo "  FAIL  no progress events"; FAILED=1; }
cmp -s "$WORK/big.bin" "$RDL/big.bin" && echo "  PASS  big file intact" || { echo "  FAIL  big file differs"; FAILED=1; }

echo "== receive: cancel from the panel mid-upload =="
start_receiver_py --throttle 0.02 || exit 1
$NU --no-config-file "$SCRIPT" send "$(rjob "$BIG")" > "$WORK/out.jsonl" 2>&1 &
SEND_PID=$!; decide accept
for _ in $(seq 1 50); do grep -q '"event": "file"' "$WORK/recv_events.jsonl" && break; sleep 0.05; done
decide cancel; wait $SEND_PID
check "cancelled event" '"event": "cancelled"' "$WORK/recv_events.jsonl"
[ -z "$(ls "$RDL" | grep '\.part$')" ] && echo "  PASS  .part removed" || { echo "  FAIL  .part left"; FAILED=1; }

echo "== receive: register is logged, log truncated on restart =="
start_receiver_py || exit 1
curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"alias":"reg","fingerprint":"REGFP","port":1,"protocol":"http"}' "http://127.0.0.1:$RPORT/api/localsend/v2/register" -o "$WORK/reg.json"
check "register answered with our info" '"alias": "fake-laptop"' "$WORK/reg.json"
grep -q ' 127.0.0.1 {"alias":"reg"' "$RDATA/registrations.log" && echo "  PASS  registration logged" || { echo "  FAIL  not logged"; cat "$RDATA/registrations.log"; FAILED=1; }
curl -s -m 2 "http://127.0.0.1:$RPORT/api/localsend/v2/info" -o "$WORK/info.json"
check "info endpoint" '"fingerprint": "RECVFINGERPRINT"' "$WORK/info.json"
kill "$RECV_PID"; wait "$RECV_PID" 2>/dev/null
python3 "$HERE/../receiver.py" --port "$RPORT" --alias x --fingerprint y --download-dir "$RDL" --data-dir "$RDATA" --favourites "$WORK/favs.json" > "$WORK/recv_events.jsonl" 2>/dev/null &
RECV_PID=$!; sleep 0.5
[ ! -s "$RDATA/registrations.log" ] && echo "  PASS  registrations.log truncated" || { echo "  FAIL  log kept"; FAILED=1; }

echo "== receive: port busy =="
python3 "$HERE/../receiver.py" --port "$RPORT" --alias x --fingerprint y --download-dir "$RDL" --data-dir "$WORK/rdata2" --favourites "$WORK/favs.json" > "$WORK/busy.jsonl" 2>/dev/null
RC=$?
check "port_busy event" '"event": "port_busy"' "$WORK/busy.jsonl"
[ "$RC" -eq 2 ] && echo "  PASS  exit code 2" || { echo "  FAIL  exit $RC"; FAILED=1; }
kill "$RECV_PID" 2>/dev/null; RECV_PID=""
```

Also extend `cleanup()` at the top of the script so a receiver never outlives a failed run:

```bash
cleanup() { pkill -f "fake_receiver.py --port $PORT" 2>/dev/null; [ -n "${RECV_PID:-}" ] && kill "$RECV_PID" 2>/dev/null; rm -rf "$WORK"; }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd noctalia/localsend-plugin && ./tests/run_tests.sh 2>&1 | grep -E "receive|FAIL" | head`
Expected: `receiver.py failed to start` (file does not exist), exit 1.

- [ ] **Step 3: Write `receiver.py`**

```python
#!/usr/bin/env python3
"""LocalSend v2 receiver for the dani/localsend noctalia plugin.

Runs for as long as the plugin service does and owns port 53317, so a phone
can send to this machine without the LocalSend desktop app. Plain HTTP.

stdout carries one JSON event per line and nothing else; the Luau side
reads it through runStream. Decisions come back as files: the panel writes
<data-dir>/decisions/<sessionId> containing accept | decline | cancel.
Diagnostics go to stderr.
"""

import argparse
import atexit
import errno
import json
import os
import secrets
import shutil
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ARGS = None
LOCK = threading.Lock()
SESSION = None  # None | {"id", "pending"} | {"id", "sender", "files", "cancelled", "uploading", "touched"}
PREFIX = "/api/localsend/v2/"
CHUNK = 256 * 1024
STALE_SECONDS = 120  # a session nobody uploads to is dropped so the next sender is not told "busy"


def emit(**event):
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()


def log(msg):
    print(f"[receiver] {msg}", file=sys.stderr, flush=True)


def self_info():
    return {
        "alias": ARGS.alias,
        "version": "2.1",
        "deviceModel": "noctalia",
        "deviceType": "desktop",
        "fingerprint": ARGS.fingerprint,
        "port": ARGS.port,
        "protocol": "http",
        "download": False,
    }


def human_rate(bytes_per_second):
    n = float(bytes_per_second)
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return ""


def is_pinned(fingerprint):
    if not fingerprint:
        return False
    try:
        with open(ARGS.favourites) as f:
            favourites = json.load(f)
        return any(d.get("fingerprint") == fingerprint for d in favourites)
    except (OSError, ValueError):
        return False


def safe_name(name):
    """Relative path with the sender's directories kept, or None if it could escape."""
    name = (name or "").strip().replace("\\", "/")
    if not name or name.startswith("/"):
        return None
    parts = [p for p in name.split("/") if p not in ("", ".")]
    if not parts or any(p == ".." for p in parts):
        return None
    return "/".join(parts)


def unique_target(relative):
    target = os.path.join(ARGS.download_dir, relative)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if not os.path.exists(target) and not os.path.exists(target + ".part"):
        return target
    base, ext = os.path.splitext(target)
    n = 1
    while os.path.exists(f"{base} ({n}){ext}") or os.path.exists(f"{base} ({n}){ext}.part"):
        n += 1
    return f"{base} ({n}){ext}"


def decision_path(session_id):
    return os.path.join(ARGS.data_dir, "decisions", session_id)


def read_decision(session_id):
    try:
        with open(decision_path(session_id)) as f:
            return f.read().strip()
    except OSError:
        return ""


def wait_decision(session_id):
    deadline = time.monotonic() + ARGS.decision_timeout
    while time.monotonic() < deadline:
        decision = read_decision(session_id)
        if decision in ("accept", "decline"):
            return decision
        time.sleep(0.2)
    return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):  # keep stdout clean; http.server logs to stderr anyway
        pass

    def _reply(self, code, payload=b"", ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    def _json(self, code, obj):
        self._reply(code, json.dumps(obj).encode())

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n > 0 else b""

    def _route(self):
        url = urlparse(self.path)
        route = url.path[len(PREFIX):] if url.path.startswith(PREFIX) else None
        return route, parse_qs(url.query)

    def _peer(self):
        return self.client_address[0]

    def do_GET(self):
        route, _ = self._route()
        if route == "info":
            return self._json(200, self_info())
        self._reply(404, b"", "text/plain")

    def do_POST(self):
        route, query = self._route()
        if route == "register":
            return self.register()
        if route == "prepare-upload":
            return self.prepare_upload()
        if route == "upload":
            return self.upload(query)
        if route == "cancel":
            return self.cancel(query)
        self._reply(404, b"", "text/plain")

    # ── discovery ──

    def register(self):
        raw = self._body()
        try:
            json.loads(raw)
        except ValueError:
            return self._reply(400, b"", "text/plain")
        line = raw.decode("utf-8", "replace").replace("\r", "").replace("\n", "")
        with open(os.path.join(ARGS.data_dir, "registrations.log"), "a") as f:
            f.write(f"{int(time.time() * 1000)} {self._peer()} {line}\n")
        self._json(200, self_info())

    # ── receiving ──

    def prepare_upload(self):
        global SESSION
        try:
            body = json.loads(self._body())
            info = body["info"]
            files = body["files"]
            assert isinstance(info, dict) and isinstance(files, dict)
        except (ValueError, KeyError, AssertionError, TypeError):
            return self._reply(400, b"", "text/plain")

        sender = {
            "alias": info.get("alias") or "unknown",
            "ip": self._peer(),
            "fingerprint": info.get("fingerprint") or "",
            "deviceType": info.get("deviceType") or "desktop",
            "deviceModel": info.get("deviceModel") or "",
        }
        entries = []
        for file_id, f in files.items():
            name = safe_name(f.get("fileName") if isinstance(f, dict) else None)
            if name is None:
                emit(event="error", message=f"rejected file name {f.get('fileName')!r} from {sender['alias']}")
                return self._reply(400, b"", "text/plain")
            entry = {
                "id": file_id,
                "name": name,
                "size": int(f.get("size") or 0),
                "type": f.get("fileType") or "application/octet-stream",
            }
            if f.get("preview"):
                entry["preview"] = str(f["preview"])[:1000]
            entries.append(entry)

        session_id = secrets.token_hex(16)
        with LOCK:
            if SESSION is not None and time.monotonic() - SESSION.get("touched", time.monotonic()) < STALE_SECONDS:
                return self._reply(409, b"", "text/plain")
            SESSION = {"id": session_id, "pending": True, "touched": time.monotonic()}

        auto = ARGS.auto_accept and is_pinned(sender["fingerprint"])
        emit(
            event="request",
            session=session_id,
            sender=sender,
            files=entries,
            total=sum(e["size"] for e in entries),
            auto=auto,
        )
        decision = "accept" if auto else wait_decision(session_id)
        if decision != "accept":
            with LOCK:
                SESSION = None
            emit(event="declined" if decision == "decline" else "timeout", session=session_id)
            return self._reply(403, b"", "text/plain")

        tokens = {}
        with LOCK:
            SESSION = {
                "id": session_id,
                "sender": sender,
                "files": {},
                "cancelled": False,
                "uploading": False,
                "touched": time.monotonic(),
            }
            for e in entries:
                token = secrets.token_hex(16)
                tokens[e["id"]] = token
                SESSION["files"][e["id"]] = {**e, "token": token, "done": False, "path": None}
        emit(event="accepted", session=session_id)
        try:
            self._json(200, {"sessionId": session_id, "files": tokens})
        except OSError:
            # The sender gave up while we waited for the decision.
            with LOCK:
                SESSION = None
            emit(event="cancelled", session=session_id)

    def upload(self, query):
        global SESSION
        session_id = (query.get("sessionId") or [""])[0]
        file_id = (query.get("fileId") or [""])[0]
        token = (query.get("token") or [""])[0]
        with LOCK:
            session = SESSION
            entry = session["files"].get(file_id) if session and session.get("files") and session["id"] == session_id else None
            if entry and entry["token"] == token and not entry["done"]:
                session["uploading"] = True
                session["touched"] = time.monotonic()
        if not entry or entry["token"] != token:
            return self._reply(403, b"", "text/plain")
        if entry["done"]:
            return self._reply(409, b"", "text/plain")

        index = list(session["files"]).index(file_id)
        total_files = len(session["files"])
        size = int(self.headers.get("Content-Length") or 0)
        try:
            target = unique_target(entry["name"])
        except OSError as e:
            with LOCK:
                SESSION = None
            emit(event="error", session=session_id, message=f"{entry['name']}: {e}")
            return self._reply(500, b"", "text/plain")
        part = target + ".part"
        emit(event="file", session=session_id, index=index, total=total_files, name=entry["name"], size=size, path=target)

        received = 0
        last_emit = time.monotonic()
        last_bytes = 0
        outcome = "ok"
        try:
            with open(part, "wb") as out:
                while received < size:
                    chunk = self.rfile.read(min(CHUNK, size - received))
                    if not chunk:
                        raise ConnectionError("body ended early")
                    out.write(chunk)
                    received += len(chunk)
                    if ARGS.throttle:
                        time.sleep(ARGS.throttle)
                    now = time.monotonic()
                    if now - last_emit >= 0.25:
                        with LOCK:
                            session["touched"] = now
                            cancelled = session["cancelled"]
                        if cancelled or read_decision(session_id) == "cancel":
                            raise ConnectionError("cancelled")
                        emit(
                            event="progress",
                            session=session_id,
                            index=index,
                            name=entry["name"],
                            percent=int(received * 100 / size) if size else 100,
                            speed=human_rate((received - last_bytes) / (now - last_emit)),
                        )
                        last_emit, last_bytes = now, received
        except ConnectionError as e:
            outcome = "cancelled" if str(e) == "cancelled" else "dropped"
        except OSError as e:
            outcome = f"error: {e}"

        if outcome != "ok":
            try:
                os.remove(part)
            except OSError:
                pass
            with LOCK:
                SESSION = None
            if outcome.startswith("error"):
                emit(event="error", session=session_id, message=f"{entry['name']}: {outcome[7:]}")
            else:
                emit(event="cancelled", session=session_id, index=index)
            if outcome != "dropped":
                try:
                    self._reply(500, b"", "text/plain")
                except OSError:
                    pass
            return

        os.replace(part, target)
        with LOCK:
            entry["done"] = True
            entry["path"] = target
            session["uploading"] = False
            all_done = all(f["done"] for f in session["files"].values())
            if all_done:
                SESSION = None
        emit(event="file_done", session=session_id, index=index, name=entry["name"], path=target)
        self._reply(200, b"", "text/plain")
        if all_done:
            emit(event="done", session=session_id, received=total_files, paths=[f["path"] for f in session["files"].values()])

    def cancel(self, query):
        global SESSION
        session_id = (query.get("sessionId") or [""])[0]
        with LOCK:
            session = SESSION
            if session and session["id"] == session_id:
                session["cancelled"] = True
                if not session.get("uploading"):
                    SESSION = None
                    emit(event="cancelled", session=session_id)
        self._reply(200, b"", "text/plain")


def main():
    global ARGS
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--port", type=int, default=53317)
    p.add_argument("--alias", default="noctalia")
    p.add_argument("--fingerprint", required=True)
    p.add_argument("--download-dir", default="~/Downloads")
    p.add_argument("--data-dir", required=True)
    p.add_argument("--favourites", required=True, help="favourites.json written by the service")
    p.add_argument("--no-auto-accept", dest="auto_accept", action="store_false", help="prompt for pinned senders too")
    p.add_argument("--decision-timeout", type=float, default=90.0)
    p.add_argument("--throttle", type=float, default=0.0, help="tests: seconds to sleep per received chunk")
    ARGS = p.parse_args()
    ARGS.download_dir = os.path.expanduser(ARGS.download_dir)

    os.makedirs(ARGS.download_dir, exist_ok=True)
    os.makedirs(ARGS.data_dir, exist_ok=True)
    decisions = os.path.join(ARGS.data_dir, "decisions")
    shutil.rmtree(decisions, ignore_errors=True)
    os.makedirs(decisions)
    open(os.path.join(ARGS.data_dir, "registrations.log"), "w").close()

    try:
        server = ThreadingHTTPServer(("0.0.0.0", ARGS.port), Handler)
    except OSError as e:
        if e.errno == errno.EADDRINUSE:
            emit(event="port_busy", port=ARGS.port)
            sys.exit(2)
        emit(event="error", message=f"bind: {e}")
        sys.exit(1)
    server.daemon_threads = True

    pidfile = os.path.join(ARGS.data_dir, "receiver.pid")
    with open(pidfile, "w") as f:
        f.write(str(os.getpid()))
    atexit.register(lambda: os.path.exists(pidfile) and os.remove(pidfile))

    emit(event="listening", port=ARGS.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests**

Run: `cd noctalia/localsend-plugin && ./tests/run_tests.sh 2>&1 | grep -E "^==|PASS|FAIL|ALL|FAILURES"`
Expected: every existing case and every new `receive:` case prints `PASS`; last line `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add noctalia/localsend-plugin/receiver.py noctalia/localsend-plugin/tests/run_tests.sh
git commit -m "feat(localsend): receiver.py, a persistent LocalSend v2 receiver with protocol tests"
```

---

### Task 2: Settings and discovery through the receiver

**Files:**
- Modify: `noctalia/localsend-plugin/plugin.toml` (add three `[[setting]]` blocks after `clear_after_send`)
- Modify: `noctalia/localsend-plugin/translations/en.json`
- Modify: `noctalia/localsend-plugin/localsend.nu` (`main discover`, remove `REGISTER_HANDLER`)
- Modify: `noctalia/localsend-plugin/tests/run_tests.sh` (the two discovery tests that used the sweep's own responder)

**Interfaces:**
- Produces: settings `download_dir`, `auto_accept_pinned`, `python_path`; `localsend.nu discover --registrations <file> [--receiver-up]`.

- [ ] **Step 1: Add the settings** — append to `plugin.toml` after the `clear_after_send` block:

```toml
[[setting]]
key = "download_dir"
type = "string"
label_key = "settings.download_dir.label"
description_key = "settings.download_dir.description"
default = "~/Downloads"

[[setting]]
key = "auto_accept_pinned"
type = "bool"
label_key = "settings.auto_accept_pinned.label"
description_key = "settings.auto_accept_pinned.description"
default = true

[[setting]]
key = "python_path"
type = "string"
label_key = "settings.python_path.label"
description_key = "settings.python_path.description"
default = "/etc/profiles/per-user/dani/bin/python3"
advanced = true
```

and to `translations/en.json` inside `"settings"`:

```json
    "download_dir": {
      "label": "Download folder",
      "description": "Where received files are saved. Existing names get a (1) suffix, never overwritten."
    },
    "auto_accept_pinned": {
      "label": "Auto-accept pinned devices",
      "description": "Devices starred in the panel are accepted without asking."
    },
    "python_path": {
      "label": "python3 path",
      "description": "python3 that runs receiver.py (the receiving server)."
    }
```

Update the description line in `plugin.toml` to `description = "Send and receive files over LocalSend: drag-and-drop or pick, choose a device — and accept incoming transfers — without the LocalSend app."`

- [ ] **Step 2: Rewrite the discovery tests** — in `tests/run_tests.sh` replace the `== discover: receiver registers over HTTP ==` block with one that runs `receiver.py` on 53317 as the register endpoint (the fake announces and registers with `http://<our lan ip>:53317`, which is now the receiver):

```bash
echo "== discover: peer registers over HTTP with receiver.py =="
rm -rf "$WORK/rdisco"; mkdir -p "$WORK/rdisco"
python3 "$HERE/../receiver.py" --port 53317 --alias fake-laptop --fingerprint TESTFINGERPRINT \
  --download-dir "$RDL" --data-dir "$WORK/rdisco" --favourites "$WORK/favs.json" > "$WORK/rdisco.jsonl" 2>/dev/null &
DISCO_PID=$!; sleep 0.5
start_receiver accept --announce --alias fake-disco || exit 1
$NU --no-config-file "$SCRIPT" discover --alias noctalia-test --fingerprint TESTFINGERPRINT --window 1500 \
  --registrations "$WORK/rdisco/registrations.log" --receiver-up > "$WORK/disco.json" 2> "$WORK/disco.err"
kill $DISCO_PID 2>/dev/null
check "found fake-disco" '"alias":"fake-disco"' "$WORK/disco.json"
if grep -q "registered with" "$WORK/receiver.log"; then
  echo "  PASS  receiver used HTTP register"
else
  echo "  FAIL  receiver did not register"; cat "$WORK/receiver.log" "$WORK/disco.err"; FAILED=1
fi
```

Move the `RDL` / `favs.json` definitions from the receive section above this block (they are needed here now), and change the `== discover: port 53317 busy -> subnet scan fallback ==` block's discover call to pass `--registrations "$WORK/nonexistent.log"` (no `--receiver-up`) and its check to `check "reported receiver down" 'receiver is not running' "$WORK/disco.err"`.

- [ ] **Step 3: Run the tests to verify the discovery ones fail**

Run: `./tests/run_tests.sh 2>&1 | grep -E "^== discover|FAIL"`
Expected: `discover` cases fail: nu rejects the unknown `--registrations` flag.

- [ ] **Step 4: Change `main discover`** — delete `const REGISTER_HANDLER = …` and the `handler` / `http` listener lines; the function becomes:

```nu
# Announce ourselves on the multicast group and collect the answers. Since the
# LocalSend core rewrite a device answers an announcement in exactly one way:
# `POST /api/localsend/v2/register` to the announcer's ip:port, over the
# protocol the announcement named. That endpoint is receiver.py (spawned by
# service.luau), which appends "<epoch ms> <ip> <body>" to --registrations for
# every register it gets; a sweep reads the lines newer than itself. The UDP
# listener stays for pre-rewrite builds that still reply by multicast, and the
# /info subnet scan covers the receiver being down (LocalSend app holding the
# port) and access points that drop multicast.
export def "main discover" [
    --socat: string = "socat"
    --curl: string = "curl"
    --alias: string = "noctalia"
    --fingerprint: string = ""
    --window: int = 2000 # ms to listen after announcing
    --registrations: string = "" # receiver.py's registrations.log
    --receiver-up # the service believes receiver.py is listening
    --scan-hosts: string = "" # tests: comma-separated hosts to probe instead of the /24
]: nothing -> nothing {
    let start = ((date now | into int) / 1_000_000 | math floor)
    let tmp = (mktemp -t "localsend-discover-XXXXXX")
    let errf = (mktemp -t "localsend-discover-err-XXXXXX")
    let udp_handler = (mktemp -t "localsend-udp-XXXXXX")
    let secs = ($window / 1000 + 0.4)

    let me = (self-info $alias $fingerprint)
    $UDP_HANDLER | str replace --all "__TMP__" (shq $tmp) | save --force $udp_handler

    let udp = $"timeout ($secs) (shq $socat) -u 'UDP4-RECVFROM:($PORT),ip-add-membership=($GROUP):0.0.0.0,reuseaddr,fork' SYSTEM:(shq $"sh ($udp_handler)") 2>> (shq $errf) &"
    ^sh -c $udp
    sleep 250ms

    let announcement = ($me | merge {announce: true, announcement: true} | to json --raw)
    for delay in [0ms 600ms] {
        sleep $delay
        $announcement | ^$socat -u - $"UDP4-DATAGRAM:($GROUP):($PORT),ip-multicast-ttl=4"
    }

    sleep (($window * 1ms) - 600ms)

    let raw = (try { open --raw $tmp | lines } catch { [] })
    let errs = (try { open --raw $errf | str trim } catch { "" })
    let registered = (try { open --raw $registrations | lines } catch { [] })
    # NB no "(s)" in these strings: parentheses inside $"..." are evaluated.
    print --stderr $"discover: ($raw | length) udp lines, ($registered | length) registration lines"
    if not $receiver_up {
        print --stderr "discover: receiver is not running (LocalSend app holding 53317?), peers cannot register; scanning the subnet instead"
    } else if ($errs | is-not-empty) {
        print --stderr $"discover: listener: ($errs | str substring 0..300)"
    }
    rm --force $tmp $errf $udp_handler

    let defaults = {alias: "unknown", deviceType: "desktop", deviceModel: "", port: $PORT, protocol: "https", fingerprint: "", download: false}
    let from_udp = ($raw
        | each {|line|
            let m = ($line | parse --regex '^PEER=(?<ip>[0-9.]+)\s*(?<body>\{.*\})$')
            if ($m | is-empty) { return null }
            let row = ($m | first)
            let payload = (try { $row.body | from json } catch { null })
            if $payload == null { return null }
            $defaults | merge $payload | insert ip $row.ip
        }
        | compact)
    let from_register = ($registered
        | each {|line|
            let m = ($line | parse --regex '^(?<ts>\d+) (?<ip>[0-9.]+) (?<body>\{.*\})$')
            if ($m | is-empty) { return null }
            let row = ($m | first)
            if ($row.ts | into int) < $start { return null }
            let payload = (try { $row.body | from json } catch { null })
            if $payload == null { return null }
            $defaults | merge $payload | insert ip $row.ip
        }
        | compact)
    let announced = ($from_udp ++ $from_register)

    let scanned = if (not $receiver_up) or ($announced | where fingerprint != $fingerprint | is-empty) {
        let found = (subnet-scan $curl $scan_hosts)
        print --stderr $"discover: subnet scan answered by ($found | length) hosts"
        $found
    } else {
        []
    }

    let devices = ($announced ++ $scanned
        | where fingerprint != $fingerprint
        | where fingerprint != ""
        | uniq-by fingerprint
        | select alias fingerprint ip port protocol deviceType deviceModel download)

    print ($devices | to json --raw)
}
```

- [ ] **Step 5: Run the full suite**

Run: `nu --no-config-file -c 'nu-check ./localsend.nu' && ./tests/run_tests.sh 2>&1 | grep -E "^==|PASS|FAIL|ALL|FAILURES"`
Expected: `true`, all `PASS`, `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add noctalia/localsend-plugin/plugin.toml noctalia/localsend-plugin/translations/en.json noctalia/localsend-plugin/localsend.nu noctalia/localsend-plugin/tests/run_tests.sh
git commit -m "feat(localsend): discovery reads receiver.py's registration log; receive settings"
```

---

### Task 3: Service — spawn, supervise, decisions, `receive` state

**Files:**
- Modify: `noctalia/localsend-plugin/service.luau`

**Interfaces:**
- Consumes: `receiver.py` CLI and events (Task 1); settings (Task 2).
- Produces: state keys `receive` (spec §5) and reads `panelOpen`; commands `{op="accept", session}`, `{op="decline", session}`, `{op="cancel_receive"}`, `{op="dismiss_receive"}`, `{op="open_folder"}`.

- [ ] **Step 1: Constants** — after `local CLEAR_AFTER …` block add:

```lua
local PYTHON = noctalia.getConfig("python_path")
local DOWNLOAD_DIR = noctalia.getConfig("download_dir") or "~/Downloads"
local AUTO_ACCEPT = noctalia.getConfig("auto_accept_pinned")
if AUTO_ACCEPT == nil then
	AUTO_ACCEPT = true
end
```

and after `local CANCEL_PATH …`:

```lua
local RECEIVER = PLUGIN .. "/receiver.py"
local RECEIVER_PID = dataDir .. "/receiver.pid"
local DECISIONS_DIR = dataDir .. "/decisions"
local REG_LOG = dataDir .. "/registrations.log"
```

- [ ] **Step 2: Discovery argv** — in `discover()`, after `"--fingerprint", FINGERPRINT,` add:

```lua
		"--registrations",
		REG_LOG,
```

and, right after the `argv` table is built:

```lua
	if receiverUp then
		argv[#argv + 1] = "--receiver-up"
	end
```

Declare `local receiverUp = false` next to `local scanning = false` (the receiver section below assigns it).

- [ ] **Step 3: Receiver section** — insert before `-- ═══ commands ═══`:

```lua
-- ═══════════════════════════════════════════════════════════ receiving ═══

-- receiver.py is the only server this plugin runs: it owns 53317 for as long
-- as the service lives. It answers peers' register/info (discovery) and takes
-- uploads. Everything it does arrives here as one JSON event per line.
local receive: { [string]: any } = { state = "off", reason = "starting" }
local receiverStartedAt = 0 -- os.time() of the last spawn, 0 = never
local receiverPortBusy = false
local busyTicks = 0

local function publishReceive()
	noctalia.state.set("receive", receive)
end

local function senderName()
	return tostring((receive.sender and receive.sender.alias) or "a device")
end

local function panelIsOpen()
	return noctalia.state.get("panelOpen") == true
end

local function humanSize(n)
	n = tonumber(n) or 0
	if n < 1024 then
		return string.format("%d B", n)
	elseif n < 1024 * 1024 then
		return string.format("%.1f KB", n / 1024)
	elseif n < 1024 * 1024 * 1024 then
		return string.format("%.1f MB", n / (1024 * 1024))
	end
	return string.format("%.2f GB", n / (1024 * 1024 * 1024))
end

local function handleReceiveEvent(ev)
	if ev.event == "listening" then
		receiverUp = true
		receiverPortBusy = false
		if receive.state == "off" then
			receive = { state = "idle" }
			publishReceive()
		end
	elseif ev.event == "port_busy" then
		receiverUp = false
		receiverPortBusy = true
		busyTicks = 0
		receive = { state = "off", reason = "port 53317 in use (LocalSend app open?)" }
		publishReceive()
	elseif ev.event == "request" then
		receive = {
			state = ev.auto and "receiving" or "waiting",
			session = ev.session,
			sender = ev.sender,
			files = ev.files,
			total = ev.total,
			percent = 0,
			index = 0,
			name = "",
			speed = "",
		}
		publishReceive()
		local n = #(ev.files or {})
		local what = n .. (n == 1 and " file" or " files") .. " (" .. humanSize(ev.total) .. ")"
		if ev.auto then
			noctalia.notify("LocalSend", "Receiving " .. what .. " from " .. senderName())
		else
			noctalia.notify("LocalSend", senderName() .. " wants to send " .. what)
			if not panelIsOpen() then
				noctalia.togglePanel("dani/localsend:panel")
			end
		end
	elseif ev.event == "accepted" then
		receive.state = "receiving"
		publishReceive()
	elseif ev.event == "declined" or ev.event == "timeout" then
		receive = { state = "declined", sender = receive.sender, message = ev.event == "timeout" and "no answer in time, declined" or "declined" }
		publishReceive()
	elseif ev.event == "file" then
		receive.state = "receiving"
		receive.index = ev.index
		receive.name = ev.name
		receive.size = ev.size
		receive.filesTotal = ev.total
		receive.percent = 0
		receive.speed = ""
		publishReceive()
	elseif ev.event == "progress" then
		receive.percent = ev.percent
		receive.speed = ev.speed
		publishReceive()
	elseif ev.event == "file_done" then
		receive.percent = 100
		publishReceive()
	elseif ev.event == "done" then
		local files = receive.files or {}
		local body
		if #files == 1 and files[1].preview then
			body = files[1].preview
		else
			body = "Received " .. tostring(ev.received) .. (ev.received == 1 and " file" or " files") .. " from " .. senderName()
		end
		noctalia.notify("LocalSend", body)
		receive = { state = "done", sender = receive.sender, received = ev.received, paths = ev.paths, message = "received " .. tostring(ev.received) }
		publishReceive()
	elseif ev.event == "cancelled" then
		noctalia.notify("LocalSend", "transfer from " .. senderName() .. " cancelled")
		receive = { state = "cancelled", sender = receive.sender, message = "cancelled" }
		publishReceive()
	elseif ev.event == "error" then
		local msg = tostring(ev.message or "receive failed")
		noctalia.notifyError("LocalSend", msg)
		if ev.session then
			receive = { state = "error", sender = receive.sender, message = msg }
			publishReceive()
		end
	end
end

local function startReceiver()
	if not noctalia.commandExists(PYTHON) then
		receive = { state = "off", reason = "python3 not found at " .. tostring(PYTHON) }
		publishReceive()
		return
	end
	receiverStartedAt = os.time()
	local cmd = table.concat({
		shq(PYTHON),
		shq(RECEIVER),
		"--port",
		"53317",
		"--alias",
		shq(ALIAS),
		"--fingerprint",
		shq(FINGERPRINT),
		"--download-dir",
		shq(DOWNLOAD_DIR),
		"--data-dir",
		shq(dataDir),
		"--favourites",
		shq(FAV_PATH),
		AUTO_ACCEPT and "" or "--no-auto-accept",
	}, " ")
	local ok = noctalia.runStream(cmd, function(line)
		if trim(line) == "" then
			return
		end
		local ev = noctalia.json.decode(line)
		if type(ev) == "table" and ev.event then
			if ev.event ~= "progress" then
				noctalia.log("receive: " .. line:sub(1, 300))
			end
			handleReceiveEvent(ev)
		else
			noctalia.log("receive: non-event output: " .. line:sub(1, 300))
		end
	end)
	if not ok then
		receive = { state = "off", reason = "could not start the receiver (too many running commands)" }
		publishReceive()
	end
end

local function decide(session, decision)
	if type(session) ~= "string" or session == "" then
		return
	end
	noctalia.mkdirAll(DECISIONS_DIR)
	noctalia.writeFile(DECISIONS_DIR .. "/" .. session, decision)
end

-- Supervision: every 15s check the pid file; respawn a dead receiver, and
-- while the port is busy retry every other tick so closing the LocalSend
-- app hands the port back within ~30s.
noctalia.setUpdateInterval(15000)
function update()
	local pid = trim(noctalia.readFile(RECEIVER_PID) or "")
	if pid == "" then
		if receiverPortBusy then
			busyTicks += 1
			if busyTicks % 2 ~= 0 then
				return
			end
		elseif os.time() - receiverStartedAt < 20 then
			return -- still starting
		end
		startReceiver()
		return
	end
	noctalia.runAsync({ "kill", "-0", pid }, function(res)
		if res.exitCode ~= 0 then
			noctalia.log("receive: receiver " .. pid .. " is gone, respawning")
			noctalia.removeFile(RECEIVER_PID)
			receiverUp = false
			receive = { state = "off", reason = "receiver crashed, restarting" }
			publishReceive()
			startReceiver()
		end
	end, 3000)
end

function onExit()
	noctalia.removeFile(RECEIVER_PID)
end
```

- [ ] **Step 4: Commands** — in the `noctalia.state.watch("command", …)` handler add before `elseif op == "fav"`:

```lua
	elseif op == "accept" then
		decide(cmd.session, "accept")
	elseif op == "decline" then
		decide(cmd.session, "decline")
	elseif op == "cancel_receive" then
		decide(receive.session, "cancel")
	elseif op == "dismiss_receive" then
		if receive.state ~= "waiting" and receive.state ~= "receiving" then
			receive = receiverUp and { state = "idle" } or { state = "off", reason = receive.reason or "receiver not running" }
			publishReceive()
		end
	elseif op == "open_folder" then
		-- `~` in DOWNLOAD_DIR cannot be expanded here (no os.getenv in the
		-- sandbox); the receiver reports absolute paths, so use those.
		local first = receive.paths and receive.paths[1]
		local dir = first and first:match("^(.*)/[^/]*$") or nil
		if dir then
			noctalia.runAsync({ "xdg-open", dir })
		end
```

- [ ] **Step 5: Startup** — in the startup section after `publishDevices()` add `publishReceive()` and `startReceiver()`; extend `onIpc` with:

```lua
	elseif event == "accept" then
		decide(receive.session, "accept")
	elseif event == "decline" then
		decide(receive.session, "decline")
```

- [ ] **Step 6: Verify live** — save the file; noctalia hot-reloads the service.

Run: `sleep 3; journalctl --user -u noctalia.service --since "-30s" --no-pager | grep -E "script-runtime\] receive" | tail -3; ss -ltnp | grep 53317`
Expected: `receive: {"event": "listening", "port": 53317}` and `python3` owning `0.0.0.0:53317`. Then `noctalia plugins lint ~/.local/share/noctalia/plugins/localsend` → `0 errors`.

Then drive a real transfer from the shell (the panel is not there yet): `nu --no-config-file localsend.nu send <job targeting 127.0.0.1:53317 http>` and `noctalia msg plugin dani/localsend:agent all accept ""` while it waits. Expected: journal shows `request` → `accepted` → `file_done` → `done`, and the file is in `~/Downloads`.

- [ ] **Step 7: Commit**

```bash
git add noctalia/localsend-plugin/service.luau
git commit -m "feat(localsend): service spawns and supervises receiver.py, publishes receive state"
```

---

### Task 4: Panel and widget

**Files:**
- Modify: `noctalia/localsend-plugin/panel.luau`
- Modify: `noctalia/localsend-plugin/widget.luau`

**Interfaces:**
- Consumes: state `receive` and commands from Task 3.
- Produces: state `panelOpen` (boolean).

- [ ] **Step 1: Panel state and header** — after `local err = noctalia.state.get("error")` add `local receive = noctalia.state.get("receive") or { state = "off" }`. In `header()`, replace the `subtitle` computation's use with a two-line column: keep `subtitle` and add a receiver line:

```lua
	local rx
	if receive.state == "off" then
		rx = "receiving off — " .. tostring(receive.reason or "not running")
	else
		rx = "receiving as " .. tostring(noctalia.getConfig("alias") or "noctalia")
	end
```

and swap the subtitle label for:

```lua
		ui.column({ gap = 0, flexGrow = 1 }, {
			ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 12 }),
			ui.label({ text = rx, color = receive.state == "off" and "error" or "on_surface_variant", fontSize = 11 }),
		}),
```

- [ ] **Step 2: Receive strips** — add after `transferStrip()`:

```lua
-- ═══════════════════════════════════════════════════════════ receiving ═══

function onAccept()
	cmd({ op = "accept", session = receive.session })
end
function onDecline()
	cmd({ op = "decline", session = receive.session })
end
function onCancelReceive()
	cmd({ op = "cancel_receive" })
end
function onDismissReceive()
	cmd({ op = "dismiss_receive" })
end
function onOpenFolder()
	cmd({ op = "open_folder" })
end

local function receiveStrip()
	local state = receive.state
	if state == nil or state == "off" or state == "idle" then
		return nil
	end
	local who = tostring((receive.sender and receive.sender.alias) or "a device")
	local ip = tostring((receive.sender and receive.sender.ip) or "")
	local glyph = DEVICE_GLYPH[(receive.sender and receive.sender.deviceType) or ""] or "device-desktop"

	if state == "waiting" then
		local rows = {}
		for i, f in ipairs(receive.files or {}) do
			if i > 6 then
				rows[#rows + 1] = ui.label({ text = "+" .. (#receive.files - 6) .. " more", color = "on_surface_variant", fontSize = 11, paddingH = 6 })
				break
			end
			rows[#rows + 1] = ui.row({ gap = 8, align = "center", paddingH = 6 }, {
				ui.glyph({ name = (f.type or ""):find("^image/") and "photo" or "file", size = 13, color = "on_surface_variant" }),
				ui.label({ text = f.name or "?", color = "on_surface", fontSize = 12, maxLines = 1, flexGrow = 1 }),
				ui.label({ text = humanSize(f.size), color = "on_surface_variant", fontSize = 11 }),
			})
		end
		local n = #(receive.files or {})
		return ui.column({ gap = 6, paddingH = 6 }, {
			ui.row({ gap = 8, align = "center" }, {
				ui.glyph({ name = glyph, size = 18, color = "tertiary" }),
				ui.label({ text = who .. " wants to send " .. n .. (n == 1 and " file" or " files") .. " · " .. humanSize(receive.total), color = "on_surface", fontSize = 13, fontWeight = "semibold", flexGrow = 1 }),
				ui.label({ text = ip, color = "on_surface_variant", fontSize = 11 }),
			}),
			ui.column({ gap = 2 }, rows),
			ui.row({ gap = 8, align = "center" }, {
				ui.spacer({ flexGrow = 1 }),
				ui.button({ text = "Decline", variant = "ghost", controlSize = "sm", onClick = "onDecline" }),
				ui.button({ text = "Accept", glyph = "download", variant = "primary", controlSize = "sm", onClick = "onAccept" }),
			}),
		})
	end

	if state == "receiving" then
		local pct = tonumber(receive.percent) or 0
		local label = tostring(receive.name or "")
		if label == "" then
			label = "Receiving from " .. who .. "..."
		elseif receive.filesTotal and tonumber(receive.filesTotal) and tonumber(receive.filesTotal) > 1 then
			label = string.format("%s (%d/%d)", label, (tonumber(receive.index) or 0) + 1, tonumber(receive.filesTotal))
		end
		local speed = (receive.speed and receive.speed ~= "") and (receive.speed .. "/s") or ""
		return ui.column({ gap = 4, paddingH = 6 }, {
			ui.row({ gap = 8, align = "center" }, {
				ui.glyph({ name = "download", size = 14, color = "primary" }),
				ui.label({ text = label, color = "on_surface", fontSize = 12, maxLines = 1, flexGrow = 1 }),
				ui.label({ text = speed, color = "on_surface_variant", fontSize = 11 }),
				ui.label({ text = pct .. "%", color = "primary", fontSize = 11, fontWeight = "semibold" }),
				ui.button({ text = "Cancel", variant = "ghost", controlSize = "sm", onClick = "onCancelReceive" }),
			}),
			ui.progress({ progress = pct / 100, fill = "primary", track = "surface_variant", height = 6, radius = 3 }),
		})
	end

	local color = (state == "done") and "primary" or (state == "error") and "error" or "on_surface_variant"
	local icon = (state == "done") and "check" or (state == "error") and "alert-triangle" or "circle-x"
	local bits = {
		ui.glyph({ name = icon, size = 14, color = color }),
		ui.label({ text = who .. ": " .. tostring(receive.message or state), color = color, fontSize = 12, maxLines = 2, flexGrow = 1 }),
	}
	if state == "done" then
		bits[#bits + 1] = ui.button({ text = "Open folder", glyph = "folder", variant = "ghost", controlSize = "sm", onClick = "onOpenFolder" })
	end
	bits[#bits + 1] = ui.button({ text = "Dismiss", variant = "ghost", controlSize = "sm", onClick = "onDismissReceive" })
	return ui.row({ gap = 8, align = "center", paddingH = 6 }, bits)
end
```

- [ ] **Step 3: Render, watchers, panelOpen** — in `render()` before `local strip = transferStrip()` add:

```lua
	local rx = receiveStrip()
	if rx then
		children[#children + 1] = ui.separator({ spacing = 4, color = "outline/0.4" })
		children[#children + 1] = rx
	end
```

Add a watcher next to the others:

```lua
noctalia.state.watch("receive", function(v)
	receive = v or { state = "off" }
	render()
end)
```

In `onOpen()` add `noctalia.state.set("panelOpen", true)` as the first line; in `onClose()` add `noctalia.state.set("panelOpen", false)`. Extend `onIpc` with `elseif event == "accept" then cmd({ op = "accept", session = receive.session }) elseif event == "decline" then cmd({ op = "decline", session = receive.session })`.

- [ ] **Step 4: Widget badge** — in `widget.luau` add `local receive = noctalia.state.get("receive") or { state = "off" }` and at the top of `render()`, before the send branches:

```lua
	local rx = receive.state
	if rx == "waiting" then
		barWidget.setGlyph("download")
		barWidget.setColor("tertiary")
		barWidget.setText("?")
		barWidget.setTooltip(tostring((receive.sender and receive.sender.alias) or "a device") .. " wants to send " .. #(receive.files or {}) .. " file(s)")
		return
	elseif rx == "receiving" then
		barWidget.setGlyph("download")
		barWidget.setColor("primary")
		barWidget.setText(tostring(receive.percent or 0) .. "%")
		local rows = {
			{ key = "from", value = tostring((receive.sender and receive.sender.alias) or "") },
			{ key = "file", value = tostring(receive.name or "") },
		}
		if receive.speed and receive.speed ~= "" then
			rows[#rows + 1] = { key = "speed", value = receive.speed .. "/s" }
		end
		barWidget.setTooltip(rows)
		return
	elseif rx == "error" then
		barWidget.setGlyph("download")
		barWidget.setColor("error")
		barWidget.setText("!")
		barWidget.setTooltip(tostring(receive.message or "receive failed"))
		return
	end
```

and a watcher:

```lua
noctalia.state.watch("receive", function(v)
	receive = v or { state = "off" }
	render()
end)
```

- [ ] **Step 5: Verify live**

Run: `noctalia plugins lint ~/.local/share/noctalia/plugins/localsend` → `0 errors`. Send from the phone (or from the shell with `localsend.nu send` to `127.0.0.1:53317`): the panel opens with the sender and files; Accept → progress → "received N"; the file is in `~/Downloads`; Decline → the sender reports declined. Pin the sender with ★, send again → no prompt, notification "Receiving …". Open the LocalSend desktop app → within ~30 s the header says "receiving off — port 53317 in use"; close it → "receiving as noctalia" returns within ~30 s.

- [ ] **Step 6: Commit**

```bash
git add noctalia/localsend-plugin/panel.luau noctalia/localsend-plugin/widget.luau
git commit -m "feat(localsend): accept prompt, receive progress and result in the panel; receive badge"
```

---

### Task 5: README and memory

**Files:**
- Modify: `noctalia/localsend-plugin/README.md`

- [ ] **Step 1: Update the README** — title line "send files over LocalSend from noctalia" → "send and receive files over LocalSend from noctalia"; add a **Receiving** paragraph under Features (prompt / pinned auto-accept / `~/Downloads` / `(1)` suffix / cancel); replace the architecture diagram with:

```
 phone ──HTTP──▶ receiver.py ──JSON events──▶ service.luau ──state──▶ panel / widget
                    ▲  (owns 53317: info, register, uploads)   │
                    └──── <dataDir>/decisions/<session> ◀───────┘  accept | decline | cancel
                    └──── <dataDir>/registrations.log ─▶ localsend.nu discover
 service.luau ── localsend.nu ── socat (announce + legacy UDP) / curl (send, /info scan)
```

Replace the "Receiving is the LocalSend app's job" gotcha with: "**The desktop app and the plugin cannot both listen on 53317.** While the app runs, the receiver stops (`port_busy`), the panel header says so, and the service retries every ~30 s; discovery falls back to the `/info` subnet scan meanwhile. Close the app to get receiving back." Add the settings rows for `download_dir`, `auto_accept_pinned`, `python_path`, and the new tests to the test list.

- [ ] **Step 2: Commit**

```bash
git add noctalia/localsend-plugin/README.md
git commit -m "docs(localsend): document the receive side"
```

- [ ] **Step 3: Update the memory note** `~/.claude/projects/-home-dani-nix-config/memory/localsend-discovery-http-only.md`: discovery now relies on `receiver.py` being up (registrations log); the "app holds 53317" symptom is now "receiving off" in the panel header. Keep the index line.
