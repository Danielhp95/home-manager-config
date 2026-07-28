#!/usr/bin/env python3
"""A minimal LocalSend v2 receiver, for testing localsend.nu without a GUI.

The real LocalSend app blocks prepare-upload until a human taps Accept, which
makes the decline / PIN / busy / cancel branches impractical to exercise by
hand. This stands in for it and can be told to misbehave on demand.

    ./fake_receiver.py --mode accept --port 8099 --out /tmp/received

Modes: accept, decline (403), pin (401 unless ?pin=1234), busy (409),
       slow (delays prepare-upload by --delay seconds, to test cancel).

Speaks plain HTTP: TLS against a self-signed cert is covered by testing
against the real LocalSend app instead.
"""

import argparse
import json
import os
import socket
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ARGS = None
SESSIONS = {}

GROUP = "224.0.0.167"
DISCOVERY_PORT = 53317
FAKE_FINGERPRINT = "FAKERECEIVER0000000000000000000000000000000000000000000000000000"


def announce_responder():
    """Answer multicast announcements the way a real LocalSend device does.

    Lets the plugin's own discovery find this receiver, so the full path
    (discover -> pick device -> send) can be tested without a human tapping
    Accept on a phone.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    sock.bind(("", DISCOVERY_PORT))
    sock.setsockopt(
        socket.IPPROTO_IP,
        socket.IP_ADD_MEMBERSHIP,
        struct.pack("4s4s", socket.inet_aton(GROUP), socket.inet_aton("0.0.0.0")),
    )
    me = {
        "alias": ARGS.alias,
        "version": "2.1",
        "deviceModel": "fake",
        "deviceType": "mobile",
        "fingerprint": FAKE_FINGERPRINT,
        "port": ARGS.port,
        "protocol": "http",
        "download": False,
        "announcement": False,
        "announce": False,
    }
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tx.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 4)
    print(f"[fake] announce responder up as '{ARGS.alias}'", flush=True)
    while True:
        try:
            data, addr = sock.recvfrom(65535)
            payload = json.loads(data.decode("utf-8", "replace"))
        except Exception:
            continue
        if payload.get("fingerprint") == FAKE_FINGERPRINT:
            continue
        if payload.get("announce"):
            tx.sendto(json.dumps(me).encode(), (GROUP, DISCOVERY_PORT))
            print(f"[fake] replied to announce from {addr[0]}", flush=True)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _reply(self, code, payload=b"", ctype="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    def do_POST(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)

        if url.path.endswith("/prepare-upload"):
            return self.prepare_upload(query)
        if url.path.endswith("/upload"):
            return self.upload(query)
        if url.path.endswith("/cancel"):
            sid = (query.get("sessionId") or [""])[0]
            SESSIONS.pop(sid, None)
            print(f"[fake] cancel session={sid}", flush=True)
            return self._reply(200)
        return self._reply(404, b"Not found")

    def prepare_upload(self, query):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")

        if ARGS.mode == "decline":
            print("[fake] declining", flush=True)
            return self._reply(403, b"Rejected")
        if ARGS.mode == "busy":
            return self._reply(409, b"Blocked by another session")
        if ARGS.mode == "pin" and (query.get("pin") or [""])[0] != "1234":
            print("[fake] wrong/absent PIN", flush=True)
            return self._reply(401, b"Invalid PIN")
        if ARGS.mode == "slow":
            print(f"[fake] stalling {ARGS.delay}s (cancel window)", flush=True)
            time.sleep(ARGS.delay)

        session = "sess-%d" % int(time.time() * 1000)
        files = body.get("files") or {}
        tokens = {fid: "tok-" + fid for fid in files}
        SESSIONS[session] = {"files": files, "tokens": tokens, "received": {}}
        print(
            "[fake] accepted session=%s from %s: %s"
            % (session, (body.get("info") or {}).get("alias"), list(files)),
            flush=True,
        )
        payload = json.dumps({"sessionId": session, "files": tokens}).encode()
        return self._reply(200, payload, "application/json")

    def upload(self, query):
        sid = (query.get("sessionId") or [""])[0]
        fid = (query.get("fileId") or [""])[0]
        token = (query.get("token") or [""])[0]
        session = SESSIONS.get(sid)
        if not session:
            return self._reply(403, b"Unknown session")
        if session["tokens"].get(fid) != token:
            return self._reply(403, b"Bad token")

        meta = session["files"].get(fid) or {}
        name = meta.get("fileName") or fid
        expected = int(meta.get("size") or 0)

        dest = os.path.join(ARGS.out, name)
        os.makedirs(os.path.dirname(dest) or ARGS.out, exist_ok=True)

        remaining = int(self.headers.get("Content-Length") or 0)
        written = 0
        with open(dest, "wb") as fh:
            while remaining > 0:
                chunk = self.rfile.read(min(65536, remaining))
                if not chunk:
                    break
                fh.write(chunk)
                written += len(chunk)
                remaining -= len(chunk)
                if ARGS.throttle:
                    time.sleep(ARGS.throttle)

        ok = written == expected
        print(
            "[fake] received %s (%d bytes, expected %d) %s"
            % (name, written, expected, "OK" if ok else "SIZE MISMATCH"),
            flush=True,
        )
        session["received"][fid] = written
        return self._reply(200)

    def log_message(self, *a):
        pass


def main():
    global ARGS
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, default=8099)
    p.add_argument("--out", default="/tmp/localsend-fake-out")
    p.add_argument(
        "--mode",
        default="accept",
        choices=["accept", "decline", "pin", "busy", "slow"],
    )
    p.add_argument("--delay", type=float, default=10.0)
    p.add_argument(
        "--throttle",
        type=float,
        default=0.0,
        help="seconds to sleep per 64KiB, to make progress observable",
    )
    p.add_argument(
        "--announce",
        action="store_true",
        help="answer multicast discovery, so the plugin can find this receiver",
    )
    p.add_argument("--alias", default="Fake Receiver")
    ARGS = p.parse_args()
    os.makedirs(ARGS.out, exist_ok=True)
    # Bind all interfaces when discoverable: the plugin learns our address from
    # the multicast packet's source, which is the LAN address, not loopback.
    host = "" if ARGS.announce else "127.0.0.1"
    if ARGS.announce:
        threading.Thread(target=announce_responder, daemon=True).start()
    print(f"[fake] listening on {ARGS.port}, mode={ARGS.mode}, out={ARGS.out}", flush=True)
    ThreadingHTTPServer((host, ARGS.port), Handler).serve_forever()


if __name__ == "__main__":
    sys.exit(main())
