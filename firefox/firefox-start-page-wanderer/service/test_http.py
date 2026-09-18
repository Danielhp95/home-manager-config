"""The HTTP surface, against a real server on a real (ephemeral) port.

These are the tests that matter most for safety: the page listens on
127.0.0.1, which every website you visit can also reach. What keeps them out
is the Host check, the absence of CORS headers, and the JSON + Origin demand
on writes. All three are asserted here rather than assumed.
"""

import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path

from _load import wanderer as w


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        root = Path(self.dir.name)

        page = root / "page"
        (page / "assets").mkdir(parents=True)
        (page / "index.html").write_text("<!doctype html><title>Wanderer</title>", encoding="utf-8")
        (page / "assets" / "style.css").write_text("body{margin:0}", encoding="utf-8")

        self.todo_path = root / "notes" / "todo.md"
        self.todo_path.parent.mkdir()
        self.todo_path.write_text("- [ ] one\n- [x] two\n", encoding="utf-8")

        self.app = w.App(
            {
                "port": 0,
                "pageDir": str(page),
                "todoFile": str(self.todo_path),
                "weather": {"place": "nowhere", "latitude": 0, "longitude": 0},
                "nixConfigDir": str(root),
                "repos": [],
                "githubUser": "nobody",
                "gitBin": "/nonexistent/git",
                "ghBin": "/nonexistent/gh",
                "ollamaUrl": "http://127.0.0.1:1",
            }
        )
        # No collectors: these tests are about the HTTP surface, and starting
        # them would reach the network.
        self.server = w.serve(self.app)
        self.port = self.server.server_address[1]
        self.app.port = self.port
        self.app.expected_host = f"127.0.0.1:{self.port}"
        self.app.expected_origin = f"http://{self.app.expected_host}"

        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    # -- helpers

    def request(self, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        self.addCleanup(connection.close)
        connection.request(method, path, body=body, headers=headers or {})
        response = connection.getresponse()
        payload = response.read()
        return response, payload

    def post_todo(self, action, body, origin=True, content_type="application/json"):
        headers = {"Content-Type": content_type}
        if origin:
            headers["Origin"] = f"http://127.0.0.1:{self.port}"
        return self.request("POST", f"/api/todo/{action}", json.dumps(body), headers)

    def version(self):
        return self.app.todo.state()["version"]

    def assertNoCors(self, response):
        for header, _ in response.getheaders():
            self.assertFalse(
                header.lower().startswith("access-control-"),
                f"{header} would let another origin read this",
            )

    # -- reading

    def test_state_is_served_and_is_not_readable_cross_origin(self):
        response, payload = self.request("GET", "/api/state")
        self.assertEqual(response.status, 200)
        state = json.loads(payload)
        self.assertEqual(
            sorted(k for k in state if k != "serverTime"), ["code", "machine", "sky", "todo"]
        )
        self.assertEqual(state["todo"]["data"]["items"][0]["text"], "one")
        self.assertNoCors(response)

    def test_an_undecodable_todo_file_breaks_one_panel_only(self):
        # A latin-1 paste in the editor that shares this file. /api/state must
        # still answer, or every panel goes dark at once.
        self.todo_path.write_bytes(b"- [ ] caf\xe9\n")
        response, payload = self.request("GET", "/api/state")
        self.assertEqual(response.status, 200)
        state = json.loads(payload)
        self.assertIsNotNone(state["todo"]["error"])
        self.assertIn("machine", state)

    def test_a_foreign_host_header_is_refused(self):
        # DNS rebinding: a hostile name resolving to 127.0.0.1.
        response, _ = self.request("GET", "/api/state", headers={"Host": "attacker.example"})
        self.assertEqual(response.status, 403)

    def test_index_and_assets(self):
        response, payload = self.request("GET", "/")
        self.assertEqual(response.status, 200)
        self.assertIn("text/html", response.getheader("Content-Type"))
        self.assertIn(b"Wanderer", payload)

        response, _ = self.request("GET", "/assets/style.css")
        self.assertEqual(response.status, 200)
        self.assertIn("text/css", response.getheader("Content-Type"))
        etag = response.getheader("ETag")
        self.assertTrue(etag)

        response, payload = self.request(
            "GET", "/assets/style.css", headers={"If-None-Match": etag}
        )
        self.assertEqual(response.status, 304)
        self.assertEqual(payload, b"")

    def test_paths_cannot_climb_out_of_the_assets_directory(self):
        for path in ("/assets/../index.html", "/assets/%2e%2e/index.html", "/assets/nope.css"):
            response, _ = self.request("GET", path)
            self.assertEqual(response.status, 404, path)

    def test_unknown_paths_are_404(self):
        response, _ = self.request("GET", "/api/secrets")
        self.assertEqual(response.status, 404)

    # -- writing

    def test_add_toggle_and_clear_done(self):
        response, payload = self.post_todo("add", {"text": "three", "version": self.version()})
        self.assertEqual(response.status, 200)
        self.assertNoCors(response)
        items = json.loads(payload)["todo"]["data"]["items"]
        self.assertEqual(items[-1]["text"], "three")

        response, payload = self.post_todo("toggle", {"line": 0, "version": self.version()})
        self.assertEqual(response.status, 200)
        self.assertTrue(json.loads(payload)["todo"]["data"]["items"][0]["done"])

        response, payload = self.post_todo("clear-done", {"version": self.version()})
        self.assertEqual(response.status, 200)
        self.assertEqual(
            [i["text"] for i in json.loads(payload)["todo"]["data"]["items"]], ["three"]
        )

    def test_a_write_without_the_right_origin_is_refused(self):
        response, _ = self.post_todo("add", {"text": "x", "version": self.version()}, origin=False)
        self.assertEqual(response.status, 403)

        headers = {"Content-Type": "application/json", "Origin": "https://evil.example"}
        response, _ = self.request(
            "POST", "/api/todo/add", json.dumps({"text": "x", "version": self.version()}), headers
        )
        self.assertEqual(response.status, 403)
        self.assertEqual(self.todo_path.read_text(encoding="utf-8"), "- [ ] one\n- [x] two\n")

    def test_a_form_style_post_is_refused(self):
        # This is the shape a hostile page can send without any preflight.
        response, _ = self.post_todo(
            "add", {"text": "x", "version": self.version()}, content_type="text/plain"
        )
        self.assertEqual(response.status, 415)

    def test_an_edit_in_nvim_wins_over_a_stale_page(self):
        stale = self.version()
        self.todo_path.write_text("- [ ] one\n- [x] two\n- [ ] added in nvim\n", encoding="utf-8")

        response, payload = self.post_todo("toggle", {"line": 0, "version": stale})
        self.assertEqual(response.status, 409)
        fresh = json.loads(payload)["todo"]["data"]["items"]
        self.assertEqual(fresh[-1]["text"], "added in nvim")
        self.assertFalse(fresh[0]["done"])

    def test_bad_requests(self):
        cases = [
            ("add", {"text": "", "version": self.version()}, 400),
            ("add", {"text": "x"}, 400),
            ("toggle", {"line": "two", "version": self.version()}, 400),
            ("toggle", {"line": 99, "version": self.version()}, 400),
            ("nonsense", {"version": self.version()}, 404),
        ]
        for action, body, expected in cases:
            response, _ = self.post_todo(action, body)
            self.assertEqual(response.status, expected, f"{action} {body}")

    def test_invalid_json_body(self):
        headers = {"Content-Type": "application/json", "Origin": self.app.expected_origin}
        response, _ = self.request("POST", "/api/todo/add", "{not json", headers)
        self.assertEqual(response.status, 400)

    def test_a_rejected_write_does_not_poison_the_connection(self):
        # Firefox keeps the connection alive. If the server rejects a POST
        # without reading its body, those bytes are read as the *next*
        # request line and the following request fails instead.
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        self.addCleanup(connection.close)

        connection.request(
            "POST",
            "/api/todo/add",
            json.dumps({"text": "x", "version": self.version()}),
            {"Content-Type": "text/plain", "Origin": self.app.expected_origin},
        )
        rejected = connection.getresponse()
        self.assertEqual(rejected.status, 415)
        rejected.read()

        connection.request("GET", "/api/state")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        response.read()

    def test_preflight_is_never_approved(self):
        headers = {
            "Origin": "https://evil.example",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        }
        response, _ = self.request("OPTIONS", "/api/todo/add", headers=headers)
        self.assertNotEqual(response.status, 200)
        self.assertNoCors(response)


if __name__ == "__main__":
    unittest.main()
