"""The todo store: the page and nvim edit the same file, so these are the
tests that keep the page from eating an editor's work."""

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from _load import wanderer as w

SAMPLE = """# today

- [ ] reboot: verify ESP loaders
- [x] blink eats Enter
notes that are not items
  - [ ] indented item
"""


class TodoStoreTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.path = Path(self.dir.name) / "notes" / "todo.md"
        self.path.parent.mkdir(parents=True)
        self.path.write_text(SAMPLE, encoding="utf-8")
        self.store = w.TodoStore(str(self.path))

    def text(self) -> str:
        return self.path.read_text(encoding="utf-8")

    # -- reading

    def test_parses_items_and_ignores_everything_else(self):
        state = self.store.state()
        self.assertEqual(
            [(i["line"], i["done"], i["text"]) for i in state["items"]],
            [(2, False, "reboot: verify ESP loaders"), (3, True, "blink eats Enter"), (5, False, "indented item")],
        )

    def test_missing_file_is_created_empty(self):
        missing = Path(self.dir.name) / "fresh" / "todo.md"
        state = w.TodoStore(str(missing)).state()
        self.assertEqual(state["items"], [])
        self.assertTrue(missing.is_file())

    # -- writing

    def test_toggle_flips_one_line_and_leaves_the_rest_byte_for_byte(self):
        version = self.store.state()["version"]
        self.store.toggle(2, version)
        self.assertEqual(
            self.text(),
            SAMPLE.replace("- [ ] reboot", "- [x] reboot"),
        )

    def test_toggle_preserves_indentation(self):
        self.store.toggle(5, self.store.state()["version"])
        self.assertIn("  - [x] indented item", self.text())

    def test_toggle_unchecks(self):
        self.store.toggle(3, self.store.state()["version"])
        self.assertIn("- [ ] blink eats Enter", self.text())

    def test_toggle_rejects_a_non_item_line(self):
        with self.assertRaises(ValueError):
            self.store.toggle(4, self.store.state()["version"])
        self.assertEqual(self.text(), SAMPLE)

    def test_toggle_rejects_a_line_outside_the_file(self):
        with self.assertRaises(ValueError):
            self.store.toggle(99, self.store.state()["version"])

    def test_add_appends_an_item(self):
        state = self.store.add("write the spec", self.store.state()["version"])
        self.assertEqual(self.text(), SAMPLE + "- [ ] write the spec\n")
        self.assertEqual(state["items"][-1]["text"], "write the spec")

    def test_add_collapses_a_pasted_paragraph_into_one_item(self):
        self.store.add("two\nlines   here", self.store.state()["version"])
        self.assertTrue(self.text().endswith("- [ ] two lines here\n"))

    def test_add_rejects_empty_text(self):
        for value in ("", "   ", "\n"):
            with self.assertRaises(ValueError):
                self.store.add(value, self.store.state()["version"])

    def test_add_to_a_file_without_a_trailing_newline(self):
        self.path.write_text("- [ ] one", encoding="utf-8")
        self.store.add("two", self.store.state()["version"])
        self.assertEqual(self.text(), "- [ ] one\n- [ ] two\n")

    def test_clear_done_removes_only_checked_items(self):
        self.store.clear_done(self.store.state()["version"])
        self.assertEqual(
            self.text(),
            SAMPLE.replace("- [x] blink eats Enter\n", ""),
        )

    # -- concurrency with the editor

    def test_a_stale_version_is_refused(self):
        stale = self.store.state()["version"]
        self.path.write_text(SAMPLE + "- [ ] added in nvim\n", encoding="utf-8")
        with self.assertRaises(w.Conflict):
            self.store.toggle(2, stale)
        self.assertIn("added in nvim", self.text())

    def test_a_missing_version_is_refused(self):
        for value in (None, "", 5):
            with self.assertRaises(ValueError):
                self.store.add("x", value)

    def test_version_changes_with_content(self):
        first = self.store.state()["version"]
        self.store.add("x", first)
        self.assertNotEqual(first, self.store.state()["version"])

    # -- durability

    def test_a_failed_write_leaves_the_file_and_no_temp_files_behind(self):
        with mock.patch.object(os, "replace", side_effect=OSError("disk went away")), \
                self.assertRaises(OSError):
            self.store.add("doomed", self.store.state()["version"])

        self.assertEqual(self.text(), SAMPLE)
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["todo.md"])


if __name__ == "__main__":
    unittest.main()
