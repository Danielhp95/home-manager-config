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
import hashlib
import json
import os
import secrets
import shutil
import signal
import socket
import ssl
import struct
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ARGS = None
LOCK = threading.Lock()
SESSION = None  # None | {"id", "pending"} | {"id", "sender", "files", "cancelled", "uploading", "touched"}
PREFIX = "/api/localsend/v2/"
GROUP = "224.0.0.167"
DISCOVERY_PORT = 53317
CHUNK = 256 * 1024
# An unauthenticated LAN peer chooses these numbers; a body is read whole.
REGISTER_MAX = 64 * 1024
PREPARE_MAX = 4 * 1024 * 1024


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


def fingerprint_proven(ip, port, claimed):
    """A LocalSend fingerprint is the SHA-256 of the device's TLS certificate.

    The request body only *claims* one, and pinned devices broadcast theirs
    on every announcement, so before skipping the prompt the sender has to
    present the certificate itself: one TLS handshake to its server, no
    request needed. A sender without a TLS server is simply prompted.
    """
    if ARGS.no_verify_pins:
        return True
    try:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with socket.create_connection((ip, int(port)), timeout=2) as raw, ctx.wrap_socket(raw) as tls:
            der = tls.getpeercert(binary_form=True)
        return bool(der) and hashlib.sha256(der).hexdigest().upper() == str(claimed).upper()
    except (OSError, ValueError, ssl.SSLError):
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


def end_session(session, event, **fields):
    """Drop `session` if it is still the active one and emit its closing event."""
    global SESSION
    with LOCK:
        if SESSION is not session:
            return
        SESSION = None
    emit(event=event, session=session["id"], **fields)


# An accepted session the sender walked away from (phone cancelled, app
# closed, skipped the rest) would otherwise sit in "receiving" until the
# next request; nothing else ever ends it. The panel's Cancel lands here
# too when no upload is running to notice the decision file.
def reaper():
    while True:
        time.sleep(0.5)
        with LOCK:
            session = SESSION
            if not session or session.get("pending") or session.get("uploading"):
                continue
            idle = time.monotonic() - session["touched"]
            cancelled = session["cancelled"] or read_decision(session["id"]) == "cancel"
        if not cancelled and idle < ARGS.idle_timeout:
            continue
        received = [f["path"] for f in session["files"].values() if f["done"]]
        if received and not cancelled:
            end_session(session, "done", received=len(received), paths=received)
        else:
            end_session(session, "cancelled")


# Peers discover us the way LocalSend does: they announce over multicast and
# expect a `register` POST back from every device that heard them. Between
# sweeps only this thread answers, so without it the laptop shows up on a
# phone only for a moment after the panel opened.
def multicast_responder():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if hasattr(socket, "SO_REUSEPORT"):
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        sock.bind(("", DISCOVERY_PORT))
        sock.setsockopt(
            socket.IPPROTO_IP,
            socket.IP_ADD_MEMBERSHIP,
            struct.pack("4s4s", socket.inet_aton(GROUP), socket.inet_aton("0.0.0.0")),
        )
    except OSError as e:
        log(f"multicast responder off: {e}")
        return
    while True:
        try:
            data, addr = sock.recvfrom(65535)
            msg = json.loads(data.decode("utf-8", "replace"))
        except (OSError, ValueError):
            continue
        if not isinstance(msg, dict) or msg.get("fingerprint") == ARGS.fingerprint:
            continue
        if not (msg.get("announce") or msg.get("announcement")):
            continue
        url = f"{msg.get('protocol') or 'https'}://{addr[0]}:{msg.get('port') or DISCOVERY_PORT}/api/localsend/v2/register"
        threading.Thread(target=post_register, args=(url,), daemon=True).start()


def post_register(url):
    req = urllib.request.Request(
        url, data=json.dumps(self_info()).encode(), headers={"Content-Type": "application/json"}
    )
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with urllib.request.urlopen(req, timeout=2, context=ctx):
            pass
    except (OSError, ValueError) as e:
        log(f"register with {url} failed: {e}")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 30  # a sender that stalls releases its thread instead of holding it forever

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

    def _body(self, limit):
        """The request body, or None after answering 413 when it exceeds `limit`."""
        n = int(self.headers.get("Content-Length") or 0)
        if n > limit:
            self.close_connection = True
            self._reply(413, b"", "text/plain")
            return None
        return self.rfile.read(n) if n > 0 else b""

    def _sender_gone(self):
        """True when the client closed its side while we were blocked on a decision."""
        try:
            self.connection.settimeout(0.0)
            return self.connection.recv(1, socket.MSG_PEEK) == b""
        except BlockingIOError:
            return False
        except OSError:
            return True
        finally:
            self.connection.settimeout(self.timeout)

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
        raw = self._body(REGISTER_MAX)
        if raw is None:
            return
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
        raw = self._body(PREPARE_MAX)
        if raw is None:
            return
        try:
            body = json.loads(raw)
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
        sender_port = info.get("port") or DISCOVERY_PORT
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
            if SESSION is not None:
                return self._reply(409, b"", "text/plain")
            SESSION = {"id": session_id, "pending": True, "touched": time.monotonic()}
        pending = SESSION

        auto = (
            ARGS.auto_accept
            and is_pinned(sender["fingerprint"])
            and fingerprint_proven(sender["ip"], sender_port, sender["fingerprint"])
        )
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
            end_session(pending, "declined" if decision == "decline" else "timeout")
            return self._reply(403, b"", "text/plain")
        if self._sender_gone():
            # The phone cancelled while the prompt was up; the RST would only
            # surface on the reply write, and on Wi-Fi often not even then.
            end_session(pending, "cancelled")
            return

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
        accepted = SESSION
        emit(event="accepted", session=session_id)
        try:
            self._json(200, {"sessionId": session_id, "files": tokens})
        except OSError:
            end_session(accepted, "cancelled")

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
            self.close_connection = True
            return self._reply(403, b"", "text/plain")
        if entry["done"]:
            self.close_connection = True
            return self._reply(409, b"", "text/plain")

        index = list(session["files"]).index(file_id)
        total_files = len(session["files"])
        size = int(self.headers.get("Content-Length") or 0)
        self.close_connection = True  # every early exit below leaves the body unread

        if session["cancelled"] or read_decision(session_id) == "cancel":
            end_session(session, "cancelled", index=index)
            return self._reply(500, b"", "text/plain")
        if size > entry["size"]:
            end_session(session, "error", message=f"{entry['name']}: larger than announced ({size} > {entry['size']} bytes)")
            return self._reply(413, b"", "text/plain")
        try:
            target = unique_target(entry["name"])
        except OSError as e:
            end_session(session, "error", message=f"{entry['name']}: {e}")
            return self._reply(500, b"", "text/plain")
        self.close_connection = False
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
            if outcome.startswith("error"):
                end_session(session, "error", message=f"{entry['name']}: {outcome[7:]}")
            else:
                end_session(session, "cancelled", index=index)
            if outcome != "dropped":
                self.close_connection = True
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
    p.add_argument("--idle-timeout", type=float, default=30.0, help="seconds an accepted session may sit without uploads")
    p.add_argument("--no-verify-pins", action="store_true", help="tests: auto-accept pinned senders without the TLS proof")
    p.add_argument("--no-multicast", action="store_true", help="tests: do not answer multicast announcements")
    p.add_argument("--throttle", type=float, default=0.0, help="tests: seconds to sleep per received chunk")
    ARGS = p.parse_args()
    ARGS.download_dir = os.path.expanduser(ARGS.download_dir)

    # Bind first: a second instance losing the port must not touch the data
    # the running one is using (decisions, registrations, pid).
    try:
        server = ThreadingHTTPServer(("0.0.0.0", ARGS.port), Handler)
    except OSError as e:
        if e.errno == errno.EADDRINUSE:
            emit(event="port_busy", port=ARGS.port)
            sys.exit(2)
        emit(event="error", message=f"bind: {e}")
        sys.exit(1)
    server.daemon_threads = True

    os.makedirs(ARGS.download_dir, exist_ok=True)
    os.makedirs(ARGS.data_dir, exist_ok=True)
    decisions = os.path.join(ARGS.data_dir, "decisions")
    shutil.rmtree(decisions, ignore_errors=True)
    os.makedirs(decisions)
    open(os.path.join(ARGS.data_dir, "registrations.log"), "w").close()

    pidfile = os.path.join(ARGS.data_dir, "receiver.pid")
    with open(pidfile, "w") as f:
        f.write(str(os.getpid()))
    atexit.register(lambda: os.path.exists(pidfile) and os.remove(pidfile))
    # atexit does not run on a bare SIGTERM, which is how the runtime stops us.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    threading.Thread(target=reaper, daemon=True).start()
    if not ARGS.no_multicast:
        threading.Thread(target=multicast_responder, daemon=True).start()

    emit(event="listening", port=ARGS.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
