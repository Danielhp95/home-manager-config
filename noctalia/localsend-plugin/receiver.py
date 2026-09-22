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
    except (OSError, ValueError, AttributeError):
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

    def log_message(self, *args):  # keep the default request log off stderr
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
            if not isinstance(f, dict):
                return self._reply(400, b"", "text/plain")
            name = safe_name(f.get("fileName"))
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
            entry = None
            if session and session.get("files") and session["id"] == session_id:
                entry = session["files"].get(file_id)
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
