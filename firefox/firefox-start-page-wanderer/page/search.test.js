// Run by `node --test` in the page derivation's checkPhase, against the
// aliases.json that nix generates from ../shared.nix. ALIASES_JSON points at
// it; the relative fallback is for running this by hand from this directory.

import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { DEFAULT_SEARCH, expandSearch, parseAliases } from "./search.js";

const aliasFile = process.env.ALIASES_JSON ?? "./assets/aliases.json";
const aliases = parseAliases(JSON.parse(readFileSync(aliasFile, "utf8")));

test("the real alias list parses", () => {
  assert.equal(aliases.size, 22);
  assert.equal(aliases.get("gs").description, "Google Scholar");
});

test("alias with a query substitutes %s, URL-encoded", () => {
  assert.equal(
    expandSearch("gs attention sinks", aliases),
    "https://scholar.google.com/scholar?hl=en&as_sdt=0%2C5&q=attention%20sinks&btnG=",
  );
});

test("alias on its own drops the placeholder", () => {
  assert.equal(expandSearch("gh", aliases), "https://github.com/");
});

test("an alias with no %s is opened as-is, like Vimium", () => {
  // sg/sgn are malformed in the export and kept verbatim (see shared.nix).
  assert.equal(
    expandSearch("sg whatever", aliases),
    "https://sourcegraph.com/search?q=context:globa",
  );
});

test("an unknown first word goes to DuckDuckGo", () => {
  assert.equal(
    expandSearch("ganglion cyst", aliases),
    `${DEFAULT_SEARCH}ganglion%20cyst`,
  );
});

test("a pasted URL is left alone", () => {
  assert.equal(
    expandSearch("  https://nixos.wiki/wiki/Flakes  ", aliases),
    "https://nixos.wiki/wiki/Flakes",
  );
});

test("empty input does nothing", () => {
  assert.equal(expandSearch("", aliases), null);
  assert.equal(expandSearch("   ", aliases), null);
});

test("an alias-looking word is not an alias unless it is one", () => {
  assert.equal(
    expandSearch("gsomething else", aliases),
    `${DEFAULT_SEARCH}gsomething%20else`,
  );
});

test("unparseable alias lines are skipped, not fatal", () => {
  const parsed = parseAliases(["good: https://example.com/%s Example", "nonsense"]);
  assert.equal(parsed.size, 1);
  assert.equal(expandSearch("good x", parsed), "https://example.com/x");
});
