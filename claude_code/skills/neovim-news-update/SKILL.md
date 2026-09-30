---
name: neovim-news-update
description: Track upstream Neovim development since the last time this skill ran, compile a report of new features and how they affect the user's personal Neovim config at ~/nix_config/danvim, then offer to apply the config changes it recommends. Use when the user wants to catch up on Neovim changes, check what's new upstream, or see how recent Neovim development impacts their config.
---

# Neovim News Update

Report what changed in upstream Neovim (`neovim/neovim`, `master` branch) since the
last time this skill ran, explain how those changes affect the user's config at
`~/nix_config/danvim`, and then **offer to apply** the changes that are ready to apply.

This is a two-punch skill:
1. **Report** (steps 1–6) — read-only research, always runs.
2. **Apply** (step 7) — concrete config edits, only after the user says yes.

Never fold punch 2 into punch 1. Write the report first and let the user see it, because
the report is what justifies the edits.

The skill directory (the folder this SKILL.md lives in) is referred to below as
`<skill-dir>`. It contains:
- `state.json` — tracks the last run (timestamp + last-seen upstream commit). May not
  exist on the first run.
- `reports/` — generated reports, one per run.

## Steps

### 1. Read the previous state

Read `<skill-dir>/state.json`. It looks like:

```json
{ "last_run_utc": "2026-06-30T22:43:15Z", "last_commit": "abc1234" }
```

- If it **does not exist** (first run), treat this as a cold start: there is no
  previous commit. Use a sensible default window of the **last 30 days** for the diff,
  and say so in the report.
- If it **exists**, the window is from `last_commit` (or `last_run_utc`) up to the
  current upstream `master` HEAD.

### 2. Fetch upstream changes

Neovim documents every notable user-facing change in `runtime/doc/news.txt` on master.
That file is the primary source. Use the GitHub API (via WebFetch) — do **not** clone.

1. Get current `master` HEAD sha and date:
   `https://api.github.com/repos/neovim/neovim/commits/master`
2. Fetch the current `news.txt`:
   `https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/news.txt`
   This file is organized newest-first under a `NEW FEATURES`, `CHANGES`,
   `DEPRECATIONS`, etc. structure per release. Focus on the unreleased / most recent
   section(s) that fall inside the window.
3. For finer detail within the window, list commits between the last-seen commit and
   HEAD touching user-facing areas:
   `https://api.github.com/repos/neovim/neovim/compare/<last_commit>...master`
   (on a cold start, skip the compare and rely on `news.txt` + the 30-day window).
   Prioritize commits with `feat`, `feat!`, `vim-patch`, and anything under
   `runtime/lua`, `runtime/doc`, LSP, treesitter, diagnostics, and the Lua API.

Be resilient: if the compare endpoint is too large or rate-limited, fall back to
`news.txt` alone and note the limitation in the report.

### 3. Read the user's config

Survey `~/nix_config/danvim` to know what the user actually uses, so relevance can be
judged. Key files:
- `lua/danvim/options.lua`, `keybindings.lua`, `builtin_plugins.lua`, `aucmds.lua`
- `lua/danvim/plugins/*.lua` — the installed plugins (lsp, treesitter, blink, snacks,
  telescope, noice, etc.)
- `flake.nix` / `packages` — this is a **nixCats** config, so the Neovim version is
  pinned via Nix; note the channel if discoverable.

Map upstream changes against this. A change is **relevant** if it: replaces a plugin the
user has, adds a native feature the user currently gets from a plugin, deprecates/breaks
an API the config calls, or changes a default the config overrides.

**Always read the pin.** Extract the locked revs and dates from `flake.lock` — the nodes
that matter are `neovim-src` (the actual Neovim source), `neovim-nightly-overlay`, and
`nixpkgs`:

```bash
python3 -c "
import json,datetime
d=json.load(open('flake.lock'))['nodes']
for k in ('neovim-src','neovim-nightly-overlay','nixpkgs','stable'):
    n=d.get(k,{}).get('locked',{})
    print(k, n.get('rev'), datetime.datetime.fromtimestamp(n['lastModified'], datetime.UTC).isoformat() if 'lastModified' in n else '')
"
```

Report how far behind master the pin is. This number drives everything in step 7 — a
feature that is on master but not at the pinned rev **cannot be adopted yet**.

**Also note private-module usage.** Grep the config for `require("vim%.` and `vim%._`
to find reaches into `vim._core`, `vim.treesitter._select`, and similar underscore
namespaces. These are the config's fragile points: they can be renamed without notice,
and when upstream promotes one to a public API, that's a high-value [ADOPT] item.

### 4. Write the report

Write `<skill-dir>/reports/neovim-news-<YYYY-MM-DD>.md` (use the current date). Use the
Bash command `date +%F` for the filename. Structure:

```markdown
# Neovim News Update — <date>

**Window:** <last run date / "cold start (30d)"> → <upstream HEAD short-sha> (<HEAD date>)
**Upstream HEAD:** <sha> — <commit subject>

## TL;DR
- 2–5 bullets: the headline changes that matter for *this* config.

## New / Notable Upstream Features
For each: what it is, and a **Relevance** line tagged one of:
[ADOPT] native feature worth enabling · [REPLACES <plugin>] · [BREAKING] · [NEUTRAL]

### <feature name>
...

## Impact on danvim config
| Area / file | Change upstream | What to do |
|---|---|---|
| `plugins/lsp.lua` | ... | ... |

### Could become obsolete
- `<plugin/setting>` — superseded by `<native feature>` (verify before removing).

### Breaking / needs attention
- `<api>` deprecated → use `<replacement>`. Affects `<file:line>`.

## Ready to apply
Changes that are safe to make **right now**, i.e. verified present at the pinned rev
(see step 4b). Each one gets a before/after snippet and the exact `file:line`.

### <change name> — `<file:line>`
```lua
-- before
<current code>
-- after
<proposed code>
```
Verified at pinned rev `<sha>`: <how — e.g. "vim.treesitter.select defined in
runtime/lua/vim/treesitter.lua">.

## Blocked on a pin bump
- `<change>` — on master (`<sha>`) but not at pinned `<sha>`. Re-check after
  `nix flake update`.

## Suggested next steps
- Concrete, ordered actions, cheapest first.

## Sources
- news.txt section(s), compare URL, key commit shas.
```

Keep it specific: cite actual file paths in danvim and actual commit shas / news.txt
headings. Don't invent features — only report what's in the fetched sources. Flag
removal suggestions as "verify before removing" since the Nix-pinned version may not yet
include the upstream change.

### 4b. Verify candidates against the *pinned* rev

Before anything lands in "Ready to apply", prove the feature exists at the rev in
`flake.lock` — **not** merely on master. Master is where the news is; the pin is what the
user actually runs. Two checks:

**Is the fix an ancestor of the pin?** Compare pinned rev → master and read the list of
commits the pin is missing:

`https://api.github.com/repos/neovim/neovim/compare/<pinned_rev>...<master_sha>`

If the commit you care about appears in that list, the pin does **not** have it → it
belongs under "Blocked on a pin bump".

**Does the API exist at the pin?** Fetch the runtime file at the pinned sha and look for
the actual signature:

`https://raw.githubusercontent.com/neovim/neovim/<pinned_rev>/runtime/lua/vim/<file>.lua`

Read the real signature and `@param` annotations rather than assuming the shape from
news.txt. A promoted-to-public API is often *reshaped* on the way out — e.g.
`vim.treesitter._select.select_child(count)` / `select_parent(count)` / `select_prev` /
`select_next` became a single `vim.treesitter.select(target, count)` with
`target: 'parent'|'child'|'next'|'prev'|'extend_next'|'extend_prev'`. Writing the edit
from the news blurb alone would have produced four calls to a function that doesn't take
those arguments.

### 5. Update state

After the report is written, overwrite `<skill-dir>/state.json` with the new HEAD sha
and the current UTC time (`date -u +%Y-%m-%dT%H:%M:%SZ`):

```json
{ "last_run_utc": "<now>", "last_commit": "<upstream HEAD sha>" }
```

### 6. Report to the user

Tell the user the report path and give the TL;DR inline. Note the Nix caveat: features
land in `danvim` only once the pinned nixpkgs/neovim input is bumped — say how far behind
the pin is and which of the window's changes it already includes.

Then close with the offer: list what's under "Ready to apply" in one line each and ask
whether to apply them. If the list is empty, say so plainly instead of inventing work.

### 7. Apply (only on a yes)

This is the second punch. It runs **only** when the user agrees, and it only ever touches
what "Ready to apply" listed — no opportunistic cleanups of unrelated code you noticed
along the way.

Rules:
- **Never edit before the report exists.** The report is the justification; if the user
  asks to apply mid-research, finish and write the report first.
- **Never apply a "Blocked on a pin bump" item.** If the user wants those, the ordered
  path is: `nix flake update` in `~/nix_config/danvim` → re-run step 4b against the new
  pin → then apply. A `nix flake update` is itself a change to the user's repo, so ask
  before running it too.
- **Re-verify at edit time**, don't trust the report blindly if the pin moved since it was
  written (e.g. the user ran `nix flake update` between the two punches). Redo the step 4b
  raw-file check for each item being applied.
- Match the surrounding style — this config uses **tabs**, and keeps one `vim.keymap.set`
  call per binding rather than collapsing them.
- Don't rebuild or `git commit` unless asked. Say plainly what changed and what's left to
  verify by hand.

After applying, list each edited `file:line` and what a smoke test would be — the config
is Nix-built, so a Lua edit under `lua/danvim/` is picked up on next launch, but anything
touching `flake.nix` / `packages/` needs a rebuild.

## Notes
- Punch 1 (steps 1–6) is **read-only** toward the config. Punch 2 (step 7) edits it, but
  only with an explicit yes and only within the report's "Ready to apply" list.
- Always update `state.json` last, only after a report is successfully written, so a
  failed run doesn't advance the window. Applying edits does **not** touch `state.json`.
- If `news.txt` shows the same section as the previous report (no new release notes in
  the window), say "no major user-facing changes since last run" rather than padding.
