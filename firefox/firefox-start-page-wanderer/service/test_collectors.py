"""Parsers for everything the panels show, against captured real output.

The fixtures in ./fixtures are verbatim from this machine (git, Open-Meteo,
ollama) so a format change upstream fails the build rather than the page.
"""

import json
import os
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from _load import wanderer as w

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def fixture(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


class GitStatusTest(unittest.TestCase):
    def test_dirty_tree(self):
        state = w.parse_git_status(fixture("git-status-dirty.txt"))
        self.assertEqual(state["branch"], "master")
        self.assertEqual(state["upstream"], "origin/master")
        self.assertEqual(state["ahead"], 4)
        self.assertEqual(state["behind"], 2)
        # ordinary + renamed + unmerged all count as work in the tree
        self.assertEqual(state["modified"], 4)
        self.assertEqual(state["untracked"], 2)
        self.assertFalse(state["detached"])

    def test_clean_tree(self):
        state = w.parse_git_status(fixture("git-status-clean.txt"))
        self.assertEqual((state["modified"], state["untracked"]), (0, 0))
        self.assertEqual((state["ahead"], state["behind"]), (0, 0))

    def test_detached_head(self):
        state = w.parse_git_status(fixture("git-status-detached.txt"))
        self.assertTrue(state["detached"])
        self.assertIsNone(state["upstream"])

    def test_no_upstream(self):
        state = w.parse_git_status(fixture("git-status-no-upstream.txt"))
        self.assertEqual(state["branch"], "wip/new-panel")
        self.assertIsNone(state["upstream"])
        self.assertEqual((state["ahead"], state["behind"]), (0, 0))

    def test_remote_urls_that_should_become_links(self):
        for remote in (
            "git@github.com:Danielhp95/regym.git",
            "https://github.com/Danielhp95/regym.git",
            "https://github.com/Danielhp95/regym",
            "ssh://git@github.com/Danielhp95/regym.git\n",
        ):
            self.assertEqual(w.git_web_url(remote), "https://github.com/Danielhp95/regym", remote)

    def test_remote_urls_that_should_not(self):
        for remote in ("git@gitlab.com:x/y.git", "/srv/git/bare.git", ""):
            self.assertIsNone(w.git_web_url(remote))

    def test_a_missing_repo_is_reported_not_raised(self):
        state = w.repo_state("/nonexistent/git", "/nonexistent/repo")
        self.assertEqual(state["error"], "missing")
        self.assertEqual(state["name"], "repo")


class SkyTest(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(fixture("open-meteo.json"))

    def test_parses_current_conditions(self):
        sky = w.parse_open_meteo(self.doc, "A Coruña")
        self.assertEqual(sky["place"], "A Coruña")
        self.assertEqual(sky["temperatureC"], 20.9)
        self.assertEqual(sky["label"], "fog")
        self.assertTrue(sky["isFog"])
        self.assertEqual(sky["cloudCover"], 44)

    def test_sun_times_are_epochs_in_the_location_s_timezone(self):
        sky = w.parse_open_meteo(self.doc, "A Coruña")
        self.assertEqual(len(sky["sun"]), 2)
        sunrise = datetime.fromtimestamp(sky["sun"][0]["sunrise"], tz=timezone.utc)
        # 08:16 local at UTC+2 is 06:16 UTC
        self.assertEqual((sunrise.hour, sunrise.minute), (6, 16))

    def test_the_location_s_utc_offset_is_carried_to_the_page(self):
        # Without it the page would print A Coruña's sunset on a machine set
        # to another timezone, which is how "sunset 14:38" happened.
        sky = w.parse_open_meteo(self.doc, "A Coruña")
        self.assertEqual(sky["utcOffsetSeconds"], 7200)

    def test_an_unknown_code_still_gets_a_label(self):
        self.doc["current"]["weather_code"] = 77777
        sky = w.parse_open_meteo(self.doc, "here")
        self.assertEqual(sky["label"], "code 77777")
        self.assertFalse(sky["isFog"])

    def test_url_has_no_key_and_asks_for_two_days(self):
        url = w.open_meteo_url(43.37, -8.4)
        self.assertIn("forecast_days=2", url)
        self.assertIn("timezone=auto", url)
        self.assertNotIn("key", url)


class OllamaTest(unittest.TestCase):
    def test_loaded_models(self):
        models = w.parse_ollama_ps(json.loads(fixture("ollama-ps.json")))
        self.assertEqual(models, [{"name": "qwen3-coder:30b", "sizeVramGb": 20.4}])

    def test_idle_daemon(self):
        self.assertEqual(w.parse_ollama_ps({"models": []}), [])

    def test_a_refused_connection_is_off_not_an_error(self):
        # Port 1 is never listening; this must not raise.
        state = w.ollama_state("http://127.0.0.1:1", timeout=1.0)
        self.assertEqual(state, {"running": False, "models": []})


class GithubTest(unittest.TestCase):
    def test_parses_search_output(self):
        prs = w.parse_gh_prs(json.loads(fixture("gh-search-prs.json")))
        self.assertEqual(prs[0]["repo"], "Danielhp95/regym")
        self.assertEqual(prs[0]["number"], 412)
        self.assertFalse(prs[0]["draft"])
        self.assertTrue(prs[1]["draft"])

    def test_missing_fields_do_not_raise(self):
        self.assertEqual(
            w.parse_gh_prs([{}])[0],
            {"number": None, "title": "", "url": None, "repo": "", "updatedAt": None, "draft": False},
        )

    def test_a_broken_gh_is_reported_as_an_error_string(self):
        state = w.github_state("/nonexistent/gh", "someone", timeout=2)
        self.assertIn("gh auth", state["error"])


class MachineTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name)

    def _system(self, name: str) -> Path:
        path = self.root / name
        for part in ("kernel", "initrd", "kernel-modules"):
            (path / part).mkdir(parents=True, exist_ok=True)
        return path

    def test_no_result_link_means_nothing_pending(self):
        current = self._system("current")
        state = w.system_state(str(self.root), str(current), str(current))
        self.assertFalse(state["switchPending"])
        self.assertFalse(state["rebootPending"])
        self.assertIsNone(state["builtAt"])

    def test_a_built_but_unswitched_system(self):
        current = self._system("nixos-system-fell-omen-26.11.now")
        built = self._system("nixos-system-fell-omen-26.11.next")
        os.symlink(built, self.root / "result")
        state = w.system_state(str(self.root), str(current), str(current))
        self.assertTrue(state["switchPending"])
        self.assertIsNotNone(state["builtAt"])

    def test_result_pointing_at_the_running_system_is_not_pending(self):
        current = self._system("nixos-system-fell-omen-26.11.now")
        os.symlink(current, self.root / "result")
        state = w.system_state(str(self.root), str(current), str(current))
        self.assertFalse(state["switchPending"])

    def test_a_result_from_building_some_package_is_ignored(self):
        current = self._system("nixos-system-fell-omen-26.11.now")
        package = self._system("hello-2.12.1")
        os.symlink(package, self.root / "result")
        state = w.system_state(str(self.root), str(current), str(current))
        self.assertFalse(state["switchPending"])

    def test_a_new_kernel_means_a_reboot_is_pending(self):
        current = self._system("current")
        booted = self._system("booted")
        (booted / "kernel").rmdir()
        (booted / "kernel").symlink_to(self.root / "old-kernel")
        state = w.system_state(str(self.root), str(current), str(booted))
        self.assertTrue(state["rebootPending"])

    def test_flake_lock_follows_the_root_input_indirection(self):
        # root's "nixpkgs" input points at the node named "nixpkgs_2".
        self.assertEqual(w.flake_lock_modified(str(FIXTURES / "flake.lock")), 1789286504)

    def test_flake_lock_without_nixpkgs(self):
        path = self.root / "flake.lock"
        path.write_text(json.dumps({"nodes": {"root": {"inputs": {}}}}), encoding="utf-8")
        self.assertIsNone(w.flake_lock_modified(str(path)))

    def test_disk_usage_looks_like_a_percentage(self):
        usage = w.disk_usage(str(self.root))
        self.assertTrue(0 <= usage["percent"] <= 100)
        self.assertGreaterEqual(usage["freeGb"], 0)

    def test_battery_absent(self):
        self.assertIsNone(w.read_battery(str(self.root / "nothing-here")))

    def test_battery_present(self):
        battery = self.root / "power" / "BAT0"
        battery.mkdir(parents=True)
        (battery / "capacity").write_text("84\n")
        (battery / "status").write_text("Discharging\n")
        self.assertEqual(
            w.read_battery(str(self.root / "power")),
            {"capacity": 84, "status": "Discharging"},
        )


class SectionTest(unittest.TestCase):
    def test_a_failure_keeps_the_last_good_data(self):
        section = w.Section(60)
        section.succeed({"n": 1})
        section.fail("boom")
        snapshot = section.snapshot()
        self.assertEqual(snapshot["data"], {"n": 1})
        self.assertEqual(snapshot["error"], "boom")

    def test_a_success_clears_the_error(self):
        section = w.Section(60)
        section.fail("boom")
        section.succeed({"n": 2})
        self.assertIsNone(section.snapshot()["error"])

    def test_a_failed_collector_retries_sooner_than_its_interval(self):
        # Logging in before the network is up must not leave the sky blank for
        # a full 15 minutes.
        waits = []

        class FakeStop:
            def __init__(self):
                self.calls = 0

            def is_set(self):
                self.calls += 1
                return self.calls > 2  # one failure, one success, then stop

            def wait(self, delay):
                waits.append(delay)

        attempts = {"n": 0}

        def collect():
            attempts["n"] += 1
            if attempts["n"] == 1:
                raise OSError("network is unreachable")
            return {"ok": True}

        w.collect_forever(w.Section(60), collect, 900, FakeStop())
        self.assertEqual(waits, [w.RETRY_AFTER_ERROR, 900])

    def test_error_phrases_are_short_and_human(self):
        self.assertEqual(
            w.describe_error(__import__("subprocess").TimeoutExpired("git", 5)), "timed out"
        )
        self.assertTrue(len(w.describe_error(RuntimeError("x" * 500))) <= 160)


if __name__ == "__main__":
    unittest.main()
