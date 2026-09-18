#!/usr/bin/env python3
"""Backend for the Firefox start page (*Wanderer above the Sea of Fog*).

Serves two things on 127.0.0.1 and nothing else:

  * the page itself, built by ../package.nix into an immutable store path
  * /api/state, one JSON object with a section per panel, plus the three
    /api/todo/* writes behind it

Everything here is Python's standard library. The only processes it starts are
`git` and `gh`, both as absolute store paths handed over in the config file.

Shape of a section:  {"data": …, "fetchedAt": epoch, "error": str|None,
"staleAfter": seconds|None}. A collector that throws keeps its last good
`data` and fills in `error`, so a panel degrades to "stale" instead of
vanishing, and one broken collector can never take the server down.

Why the Host and Origin checks matter (they are not ceremony): any website you
visit can make your browser send requests to 127.0.0.1. Reading is already
blocked by never emitting CORS headers, but a plain form POST needs no
permission, so the writes demand application/json (which forces a preflight
this server never approves) plus the exact Origin. The Host check blocks DNS
rebinding, where a hostile name resolves to 127.0.0.1 and thus counts as a
different origin with the same address.
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

USER_AGENT = "firefox-start-page-wanderer/1.0"

# How often each collector runs, and how old its data may get before the page
# calls it stale. Stale is generous on purpose: a 15-minute weather reading is
# still worth showing, it just says so.
SKY_INTERVAL, SKY_STALE = 15 * 60, 45 * 60
MACHINE_INTERVAL, MACHINE_STALE = 60, 5 * 60
CODE_INTERVAL, CODE_STALE = 60, 15 * 60
GITHUB_INTERVAL = 5 * 60
RETRY_AFTER_ERROR = 60


# --------------------------------------------------------------------------
# small shared helpers
# --------------------------------------------------------------------------


def describe_error(exc: BaseException) -> str:
    """A short, human phrase for a panel. Never a traceback, never a token."""
    if isinstance(exc, subprocess.TimeoutExpired):
        return "timed out"
    if isinstance(exc, subprocess.CalledProcessError):
        tail = (exc.stderr or "").strip().splitlines()
        return (tail[-1][:120] if tail else f"exit {exc.returncode}")
    if isinstance(exc, urllib.error.URLError):
        return str(exc.reason)[:120]
    return f"{type(exc).__name__}: {exc}"[:160]


def run(cmd: list[str], timeout: float, env: dict[str, str] | None = None) -> str:
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout, env=env, check=False
    )
    if proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd, proc.stdout, proc.stderr)
    return proc.stdout


def fetch_json(url: str, timeout: float = 10.0):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


# --------------------------------------------------------------------------
# sections and collectors
# --------------------------------------------------------------------------


class Section:
    """One panel's cache: last good data, when it arrived, last error."""

    def __init__(self, stale_after: float | None):
        self.stale_after = stale_after
        self._lock = threading.Lock()
        self._data = None
        self._fetched_at: float | None = None
        self._error: str | None = None

    def succeed(self, data) -> None:
        with self._lock:
            self._data = data
            self._fetched_at = time.time()
            self._error = None

    def fail(self, error: str) -> None:
        with self._lock:
            self._error = error

    def snapshot(self) -> dict:
        with self._lock:
            return {
                "data": self._data,
                "fetchedAt": self._fetched_at,
                "error": self._error,
                "staleAfter": self.stale_after,
            }


def fresh(data, error: str | None = None) -> dict:
    """A section computed on demand rather than by a collector."""
    return {"data": data, "fetchedAt": time.time(), "error": error, "staleAfter": None}


def collect_forever(section: Section, collect, interval: float, stop: threading.Event) -> None:
    while not stop.is_set():
        try:
            section.succeed(collect())
            delay = interval
        except Exception as exc:  # noqa: BLE001 - a panel may fail; the server may not
            section.fail(describe_error(exc))
            # Retry sooner than the normal interval. Otherwise a login with
            # the network still coming up leaves the sky blank, and the art
            # without weather, for the whole 15 minutes.
            delay = min(interval, RETRY_AFTER_ERROR)
        stop.wait(delay)


# --------------------------------------------------------------------------
# sky: Open-Meteo, no API key
# --------------------------------------------------------------------------

WMO_LABELS = {
    0: "clear",
    1: "mostly clear",
    2: "partly cloudy",
    3: "overcast",
    45: "fog",
    48: "freezing fog",
    51: "light drizzle",
    53: "drizzle",
    55: "heavy drizzle",
    56: "freezing drizzle",
    57: "freezing drizzle",
    61: "light rain",
    63: "rain",
    65: "heavy rain",
    66: "freezing rain",
    67: "freezing rain",
    71: "light snow",
    73: "snow",
    75: "heavy snow",
    77: "snow grains",
    80: "showers",
    81: "showers",
    82: "heavy showers",
    85: "snow showers",
    86: "snow showers",
    95: "thunderstorm",
    96: "thunderstorm, hail",
    99: "thunderstorm, hail",
}
FOG_CODES = {45, 48}


def open_meteo_url(latitude: float, longitude: float) -> str:
    query = urllib.parse.urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "current": "temperature_2m,weather_code,cloud_cover,visibility",
            "daily": "sunrise,sunset",
            "timezone": "auto",
            "forecast_days": 2,
        }
    )
    return f"https://api.open-meteo.com/v1/forecast?{query}"


def local_epoch(stamp: str, utc_offset_seconds: int) -> int:
    """`timezone=auto` returns wall-clock times *at the location*, with no
    offset in the string, so the offset has to come from the document."""
    naive = datetime.fromisoformat(stamp)
    return int(naive.replace(tzinfo=timezone(timedelta(seconds=utc_offset_seconds))).timestamp())


def parse_open_meteo(doc: dict, place: str) -> dict:
    current = doc["current"]
    offset = int(doc.get("utc_offset_seconds", 0))
    daily = doc.get("daily", {})
    code = int(current.get("weather_code", 0))
    return {
        "place": place,
        "temperatureC": current.get("temperature_2m"),
        "weatherCode": code,
        "label": WMO_LABELS.get(code, f"code {code}"),
        "isFog": code in FOG_CODES,
        "cloudCover": current.get("cloud_cover"),
        "visibilityM": current.get("visibility"),
        # Sunrise and sunset belong to the *place*, which is not necessarily
        # the timezone this machine is set to (the laptop travels). The page
        # formats them with this offset rather than the browser's.
        "utcOffsetSeconds": offset,
        "sun": [
            {"sunrise": local_epoch(rise, offset), "sunset": local_epoch(set_, offset)}
            for rise, set_ in zip(daily.get("sunrise", []), daily.get("sunset", []))
        ],
    }


# --------------------------------------------------------------------------
# machine
# --------------------------------------------------------------------------


def system_state(
    nix_config_dir: str,
    current: str = "/run/current-system",
    booted: str = "/run/booted-system",
) -> dict:
    """What `./result` and /run say about switching and rebooting.

    `switchPending` only ever sees builds that leave a ./result symlink behind
    (`nixos-rebuild build`, or `nh os build --out-link result`); an `nh os
    build` into a temporary link is invisible here. The basename check keeps a
    ./result left over from building some *package* from being read as a
    system that is waiting to be switched to.
    """
    result_link = os.path.join(nix_config_dir, "result")
    current_path = os.path.realpath(current)

    switch_pending = False
    built_at = None
    if os.path.islink(result_link):
        built = os.path.realpath(result_link)
        if "nixos-system-" in os.path.basename(built) and os.path.exists(built):
            built_at = os.lstat(result_link).st_mtime
            switch_pending = built != current_path

    reboot_pending = any(
        os.path.realpath(os.path.join(booted, part))
        != os.path.realpath(os.path.join(current, part))
        for part in ("kernel", "initrd", "kernel-modules")
    )

    return {
        "switchPending": switch_pending,
        "builtAt": built_at,
        "rebootPending": reboot_pending,
    }


def flake_lock_modified(lock_path: str) -> int | None:
    """`lastModified` of whatever the root's `nixpkgs` input resolves to.

    The indirection is the point: in this flake.lock the root input named
    "nixpkgs" points at a node called "nixpkgs_2".
    """
    doc = json.loads(Path(lock_path).read_text(encoding="utf-8"))
    nodes = doc.get("nodes", {})
    name = nodes.get("root", {}).get("inputs", {}).get("nixpkgs")
    if isinstance(name, list):  # a follows-path, e.g. ["danvim", "nixpkgs"]
        name = name[-1]
    node = nodes.get(name) if isinstance(name, str) else None
    if not node:
        return None
    return node.get("locked", {}).get("lastModified")


def disk_usage(path: str) -> dict:
    st = os.statvfs(path)
    total = st.f_blocks * st.f_frsize
    used = total - st.f_bfree * st.f_frsize
    free = st.f_bavail * st.f_frsize
    return {
        "percent": round(used / total * 100) if total else 0,
        "freeGb": round(free / 1e9, 1),
    }


def read_battery(root: str = "/sys/class/power_supply") -> dict | None:
    base = Path(root)
    if not base.is_dir():
        return None
    for entry in sorted(base.glob("BAT*")):
        try:
            return {
                "capacity": int((entry / "capacity").read_text().strip()),
                "status": (entry / "status").read_text().strip(),
            }
        except (OSError, ValueError):
            continue
    return None


def parse_ollama_ps(doc: dict) -> list[dict]:
    models = []
    for model in doc.get("models", []) or []:
        models.append(
            {
                "name": model.get("name") or model.get("model") or "?",
                "sizeVramGb": round((model.get("size_vram") or 0) / 1e9, 1),
            }
        )
    return models


def ollama_state(base_url: str, timeout: float = 3.0) -> dict:
    try:
        doc = fetch_json(f"{base_url.rstrip('/')}/api/ps", timeout=timeout)
    except (urllib.error.URLError, OSError, ValueError):
        # Not an error: ollama being off is a normal state to report.
        return {"running": False, "models": []}
    return {"running": True, "models": parse_ollama_ps(doc)}


# --------------------------------------------------------------------------
# code: local git, then GitHub through gh
# --------------------------------------------------------------------------


def parse_git_status(text: str) -> dict:
    """`git status --porcelain=v2 --branch`, counted."""
    state = {
        "branch": None,
        "upstream": None,
        "ahead": 0,
        "behind": 0,
        "modified": 0,
        "untracked": 0,
        "detached": False,
    }
    for line in text.splitlines():
        if line.startswith("# branch.head "):
            head = line.split(" ", 2)[2]
            state["branch"] = head
            state["detached"] = head == "(detached)"
        elif line.startswith("# branch.upstream "):
            state["upstream"] = line.split(" ", 2)[2]
        elif line.startswith("# branch.ab "):
            _, _, ahead, behind = line.split()
            state["ahead"] = int(ahead)
            state["behind"] = -int(behind)
        elif line[:2] in ("1 ", "2 ", "u "):
            state["modified"] += 1
        elif line.startswith("? "):
            state["untracked"] += 1
    return state


GITHUB_REMOTE = re.compile(
    r"^(?:git@github\.com:|(?:https?|ssh)://(?:[^@/]+@)?github\.com/)"
    r"(?P<slug>[^/]+/[^/]+?)(?:\.git)?/?$"
)


def git_web_url(remote: str) -> str | None:
    match = GITHUB_REMOTE.match(remote.strip())
    return f"https://github.com/{match.group('slug')}" if match else None


def repo_state(git_bin: str, path: str, timeout: float = 5.0) -> dict:
    name = os.path.basename(path.rstrip("/"))
    if not os.path.isdir(path):
        return {"name": name, "path": path, "error": "missing"}
    try:
        status = parse_git_status(
            run([git_bin, "-C", path, "status", "--porcelain=v2", "--branch"], timeout)
        )
    except Exception as exc:  # noqa: BLE001 - one bad repo must not blank the panel
        return {"name": name, "path": path, "error": describe_error(exc)}

    status.update({"name": name, "path": path, "webUrl": None})
    with contextlib.suppress(Exception):  # a repo with no origin is fine
        status["webUrl"] = git_web_url(run([git_bin, "-C", path, "remote", "get-url", "origin"], timeout))
    return status


PR_FIELDS = "number,title,url,repository,updatedAt,isDraft"


def parse_gh_prs(doc: list) -> list[dict]:
    prs = []
    for item in doc:
        repo = item.get("repository") or {}
        prs.append(
            {
                "number": item.get("number"),
                "title": (item.get("title") or "").strip(),
                "url": item.get("url"),
                "repo": repo.get("nameWithOwner") or repo.get("name") or "",
                "updatedAt": item.get("updatedAt"),
                "draft": bool(item.get("isDraft")),
            }
        )
    return prs


def github_state(gh_bin: str, user: str, timeout: float = 15.0, limit: int = 5) -> dict:
    """Open PRs for `user`, via a token taken fresh from gh's keyring.

    The token lives in this function's `env` and nowhere else: not on disk, not
    in the state document, not in a log line.
    """
    try:
        token = run([gh_bin, "auth", "token", "--user", user], timeout).strip()
    except Exception as exc:  # noqa: BLE001
        return {"error": f"gh auth: {describe_error(exc)}"}
    if not token:
        return {"error": "gh auth: no token"}

    env = {k: v for k, v in os.environ.items() if k not in ("GITHUB_TOKEN", "GH_TOKEN")}
    env["GH_TOKEN"] = token

    def search(selector: str) -> list[dict]:
        raw = run(
            [
                gh_bin, "search", "prs", "--state=open", selector,
                f"--limit={limit}", "--json", PR_FIELDS,
            ],
            timeout,
            env=env,
        )
        return parse_gh_prs(json.loads(raw))

    try:
        return {"review": search("--review-requested=@me"), "mine": search("--author=@me")}
    except Exception as exc:  # noqa: BLE001
        return {"error": describe_error(exc)}


# --------------------------------------------------------------------------
# today: a markdown checklist the page and nvim share
# --------------------------------------------------------------------------

ITEM_RE = re.compile(r"^(?P<indent>\s*)- \[(?P<mark>[ xX])\] (?P<text>.*)$")
MAX_ITEM_CHARS = 500


class Conflict(Exception):
    """The file changed since the page rendered it."""


class TodoStore:
    """Reads and writes `- [ ] …` lines, leaving every other line alone.

    Concurrency with nvim is optimistic: each write carries the version (a
    hash) the page last saw. A mismatch raises Conflict rather than
    overwriting an edit made in the editor.
    """

    def __init__(self, path: str):
        self.path = Path(path)
        self._lock = threading.Lock()

    # -- reading

    def _read(self) -> str:
        try:
            return self.path.read_text(encoding="utf-8")
        except FileNotFoundError:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text("", encoding="utf-8")
            return ""

    @staticmethod
    def version(text: str) -> str:
        return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

    @staticmethod
    def parse(text: str) -> list[dict]:
        items = []
        for number, line in enumerate(text.splitlines()):
            match = ITEM_RE.match(line)
            if match:
                items.append(
                    {
                        "line": number,
                        "done": match["mark"] in "xX",
                        "text": match["text"].strip(),
                    }
                )
        return items

    def _snapshot(self, text: str) -> dict:
        return {
            "path": str(self.path),
            "version": self.version(text),
            "items": self.parse(text),
        }

    def state(self) -> dict:
        with self._lock:
            return self._snapshot(self._read())

    # -- writing

    def _write(self, text: str) -> None:
        """Temp file in the same directory, then rename: a reader (or a crash)
        never sees a half-written list."""
        directory = self.path.parent
        directory.mkdir(parents=True, exist_ok=True)
        fd, temp = tempfile.mkstemp(dir=directory, prefix=".todo-", suffix=".md")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(text)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temp, 0o644)
            os.replace(temp, self.path)
        except BaseException:
            os.unlink(temp)
            raise

    def _mutate(self, version, change) -> dict:
        if not isinstance(version, str) or not version:
            raise ValueError("version required")
        with self._lock:
            text = self._read()
            if version != self.version(text):
                raise Conflict("file changed on disk")
            updated = change(text)
            if updated != text:
                self._write(updated)
            return self._snapshot(updated)

    def toggle(self, line, version) -> dict:
        if not isinstance(line, int) or isinstance(line, bool):
            raise TypeError("line must be an integer")

        def change(text: str) -> str:
            lines = text.splitlines(keepends=True)
            if not 0 <= line < len(lines):
                raise ValueError("no such line")
            raw = lines[line]
            body = raw.rstrip("\n")
            match = ITEM_RE.match(body)
            if not match:
                raise ValueError("not a checklist item")
            mark = " " if match["mark"] in "xX" else "x"
            ending = raw[len(body):]
            lines[line] = f"{match['indent']}- [{mark}] {match['text']}{ending}"
            return "".join(lines)

        return self._mutate(version, change)

    def add(self, text, version) -> dict:
        if not isinstance(text, str):
            raise TypeError("text must be a string")
        # One line, always: a pasted paragraph would otherwise become several
        # items, only the first of which is a checklist entry.
        cleaned = " ".join(text.split())[:MAX_ITEM_CHARS]
        if not cleaned:
            raise ValueError("empty item")

        def change(existing: str) -> str:
            prefix = existing if not existing or existing.endswith("\n") else existing + "\n"
            return f"{prefix}- [ ] {cleaned}\n"

        return self._mutate(version, change)

    def clear_done(self, version) -> dict:
        def change(text: str) -> str:
            kept = []
            for line in text.splitlines(keepends=True):
                match = ITEM_RE.match(line.rstrip("\n"))
                if match and match["mark"] in "xX":
                    continue
                kept.append(line)
            return "".join(kept)

        return self._mutate(version, change)


# --------------------------------------------------------------------------
# the application
# --------------------------------------------------------------------------


class App:
    def __init__(self, config: dict):
        self.config = config
        self.port = int(config["port"])
        self.page_dir = Path(config["pageDir"]).resolve()
        self.assets_dir = self.page_dir / "assets"
        self.expected_host = f"127.0.0.1:{self.port}"
        self.expected_origin = f"http://{self.expected_host}"
        self.todo = TodoStore(config["todoFile"])
        self.sections = {
            "sky": Section(SKY_STALE),
            "machine": Section(MACHINE_STALE),
            "code": Section(CODE_STALE),
        }
        # Changes with every rebuild, so an asset ETag can never outlive the
        # build it came from.
        self.build_tag = hashlib.sha256(str(self.page_dir).encode()).hexdigest()[:12]
        self.stop = threading.Event()

    # -- collectors

    def collect_sky(self) -> dict:
        weather = self.config["weather"]
        doc = fetch_json(open_meteo_url(weather["latitude"], weather["longitude"]))
        return parse_open_meteo(doc, weather["place"])

    def collect_machine(self) -> dict:
        nix_dir = self.config["nixConfigDir"]
        state = system_state(nix_dir)
        state["flakeLockModified"] = flake_lock_modified(os.path.join(nix_dir, "flake.lock"))
        state["disk"] = disk_usage(str(Path.home()))
        state["battery"] = read_battery()
        state["ollama"] = ollama_state(self.config["ollamaUrl"])
        return state

    def make_code_collector(self):
        """git every minute, GitHub every five: the same panel, two clocks."""
        cache: dict = {"github": None, "at": 0.0}

        def collect() -> dict:
            repos = [repo_state(self.config["gitBin"], path) for path in self.config["repos"]]
            now = time.time()
            if cache["github"] is None or now - cache["at"] >= GITHUB_INTERVAL:
                cache["github"] = github_state(self.config["ghBin"], self.config["githubUser"])
                cache["at"] = now
            return {"repos": repos, "github": cache["github"]}

        return collect

    def start_collectors(self) -> None:
        for section, collect, interval in (
            (self.sections["sky"], self.collect_sky, SKY_INTERVAL),
            (self.sections["machine"], self.collect_machine, MACHINE_INTERVAL),
            (self.sections["code"], self.make_code_collector(), CODE_INTERVAL),
        ):
            threading.Thread(
                target=collect_forever,
                args=(section, collect, interval, self.stop),
                daemon=True,
            ).start()

    # -- state

    def state(self) -> dict:
        payload: dict = {"serverTime": time.time()}
        for name, section in self.sections.items():
            payload[name] = section.snapshot()
        try:
            payload["todo"] = fresh(self.todo.state())
        except (OSError, ValueError) as exc:
            # ValueError covers UnicodeDecodeError: a latin-1 paste into
            # ~/notes/todo.md from the editor sharing this file must degrade
            # to one panel showing an error, not take /api/state down and
            # blank every panel.
            payload["todo"] = fresh(None, describe_error(exc))
        return payload


CONTENT_TYPES = {
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".jpg": "image/jpeg",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ttf": "font/ttf",
    ".woff2": "font/woff2",
}


def make_handler(app: App):
    class Handler(BaseHTTPRequestHandler):
        server_version = "wanderer"
        sys_version = ""
        protocol_version = "HTTP/1.1"

        # The page polls every 30s; logging that is just noise in journald.
        def log_message(self, format, *args):  # `format`: the base class spells it that way
            pass

        def log_error(self, format, *args):
            print(f"wanderer: {format % args}", file=sys.stderr, flush=True)

        # -- plumbing

        def _finish(self, status, body=b"", content_type="text/plain; charset=utf-8", headers=None):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            for key, value in (headers or {}).items():
                self.send_header(key, value)
            self.end_headers()
            if self.command != "HEAD" and body:
                self.wfile.write(body)

        def _json(self, status, payload, headers=None):
            self._finish(
                status,
                json.dumps(payload).encode("utf-8"),
                "application/json; charset=utf-8",
                {"Cache-Control": "no-store", **(headers or {})},
            )

        def _host_ok(self) -> bool:
            if self.headers.get("Host") == app.expected_host:
                return True
            # Nothing further is read from a connection addressed to the wrong
            # name, so it cannot be kept alive.
            self.close_connection = True
            self._finish(403, b"forbidden host\n")
            return False

        def _send_file(self, path: Path, headers=None):
            try:
                body = path.read_bytes()
            except OSError:
                self._finish(404, b"not found\n")
                return
            self._finish(
                200,
                body,
                CONTENT_TYPES.get(path.suffix, "application/octet-stream"),
                headers,
            )

        # -- routes

        def do_GET(self):
            if not self._host_ok():
                return
            path = urllib.parse.urlsplit(self.path).path

            if path == "/api/state":
                self._json(200, app.state())
                return
            if path in ("/", "/index.html"):
                self._send_file(app.page_dir / "index.html", {"Cache-Control": "no-cache"})
                return
            if path.startswith("/assets/"):
                self._send_asset(path)
                return
            self._finish(404, b"not found\n")

        def do_HEAD(self):
            self.do_GET()

        def _send_asset(self, path: str):
            relative = urllib.parse.unquote(path[len("/assets/") :])
            target = (app.assets_dir / relative).resolve()
            root = str(app.assets_dir.resolve())
            if not str(target).startswith(root + os.sep) or not target.is_file():
                self._finish(404, b"not found\n")
                return
            # Asset URLs are stable across rebuilds, so they get an ETag tied
            # to the store path instead of a cache-busting query string.
            etag = f'"{app.build_tag}-{hashlib.sha256(relative.encode()).hexdigest()[:8]}"'
            if self.headers.get("If-None-Match") == etag:
                self._finish(304, b"", "text/plain", {"ETag": etag, "Cache-Control": "no-cache"})
                return
            self._send_file(target, {"ETag": etag, "Cache-Control": "no-cache"})

        def do_POST(self):
            if not self._host_ok():
                return
            path = urllib.parse.urlsplit(self.path).path
            if not path.startswith("/api/todo/"):
                self._finish(404, b"not found\n")
                return

            # Read the body *before* any rejection. On a keep-alive
            # connection an unread body is parsed as the next request line,
            # which breaks the following request rather than this one.
            try:
                length = int(self.headers.get("Content-Length") or 0)
            except ValueError:
                self.close_connection = True
                self._json(400, {"error": "bad content-length"})
                return
            if length > 64 * 1024:
                self.close_connection = True
                self._json(413, {"error": "too large"})
                return
            raw = self.rfile.read(length)

            content_type = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
            if content_type != "application/json":
                self._json(415, {"error": "expected application/json"})
                return
            if self.headers.get("Origin") != app.expected_origin:
                self._json(403, {"error": "bad origin"})
                return

            try:
                body = json.loads(raw or b"{}")
            except ValueError:
                self._json(400, {"error": "invalid json"})
                return
            if not isinstance(body, dict):
                self._json(400, {"error": "expected an object"})
                return

            action = path[len("/api/todo/") :]
            version = body.get("version")
            try:
                if action == "toggle":
                    todo = app.todo.toggle(body.get("line"), version)
                elif action == "add":
                    todo = app.todo.add(body.get("text"), version)
                elif action == "clear-done":
                    todo = app.todo.clear_done(version)
                else:
                    self._finish(404, b"not found\n")
                    return
            except Conflict:
                self._json(409, {"error": "file changed on disk", "todo": fresh(app.todo.state())})
                return
            except (TypeError, ValueError) as exc:
                self._json(400, {"error": str(exc)})
                return
            except OSError as exc:
                self._json(500, {"error": describe_error(exc)})
                return

            self._json(200, {"todo": fresh(todo)})

    return Handler


def serve(app: App) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(("127.0.0.1", app.port), make_handler(app))
    server.daemon_threads = True
    return server


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: firefox-start-page-wanderer <config.json>", file=sys.stderr)
        return 2
    config = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    app = App(config)
    app.start_collectors()
    server = serve(app)
    print(f"wanderer: serving {app.expected_origin} from {app.page_dir}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        app.stop.set()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
