---
name: repo-news
description: Catch up on an upstream repository the user depends on. Takes the repo as its one argument (`/repo-news neovim`, `/repo-news noctalia`, or any name, owner/repo or URL), reports what changed upstream since the last run for that repo and how it affects the user's own setup in ~/nix_config, then offers to apply the config changes it recommends. Use whenever the user asks what's new in Neovim, Noctalia or any other project they pin or configure, wants to know what a version bump brings or breaks, asks whether a workaround is still needed, or names a repo they want tracked from now on — a repo not seen before gets its own memory and logs.
argument-hint: [repo]
---

# Repo News

Report what changed in one upstream repository since the last time this skill ran for
it, explain how those changes affect the user's own setup, and then **offer to apply**
the changes that are ready to apply.

**Requested repo:** `$ARGUMENTS`

(If that line is empty or still shows a literal placeholder, take the repo from the
user's message. If there is none there either, list the known repos and ask which.)

This is a two-punch skill:
1. **Report** (steps 1–6) — read-only research, always runs.
2. **Apply** (step 7) — concrete config edits, only after the user says yes.

Never fold punch 2 into punch 1. Write the report first and let the user see it, because
the report is what justifies the edits.

## Where things live

`<skill-dir>` is `~/.claude/skills/repo-news` — the base directory given when the skill
is invoked. Use that path, not the Nix store path `SKILL.md` links to: the store is
read-only and holds none of the state.

Each tracked repo has one directory, `<skill-dir>/repos/<slug>/`:
- `profile.md` — the **memory**: what the repo is, where its news is published, where
  the user's setup for it lives, how it is pinned, how to verify and apply. Frontmatter
  carries `slug`, `upstream`, `branch` and `aliases`.
- `notes.md` — lessons from earlier runs (may not exist).
- `state.json` — the last run: timestamp, last-seen upstream commit, and whatever else
  the profile asks to keep (e.g. the last release tag). May not exist on the first run.
- `reports/` — the **logs**: one report per run.

A `profile.md` that is a symlink into the Nix store ships with the user's config; its
source is `~/nix_config/home/claude-code/skills/repo-news/repos/<slug>/profile.md`. Treat it
as read-only and put anything learned in `notes.md`.

## Steps

### 0. Resolve the repo

List what is already tracked — read the frontmatter of every
`<skill-dir>/repos/*/profile.md`. Normalize the argument (lowercase; strip a host
prefix, `.git`, trailing slashes) and compare it against each profile's `slug`,
`upstream` (both `owner/repo` and the bare repo name) and `aliases`.

- **It names a tracked repo** (exact or alias: `nvim`, `neovim/neovim`,
  `https://github.com/neovim/neovim`) → use that profile.
- **It is near a tracked repo** (a typo, a missing or extra letter, a variant name:
  `noctlia`, `neovmi`, `noctalia-shell`) → decide the way a colleague would:
  - *Go* when one reading is clearly the likeliest — the argument is not itself a real
    project the user plausibly means, and only one tracked repo is close. Say so in one
    line ("Reading `noctlia` as noctalia.") and carry on; the user can interrupt.
  - *Ask* when two readings are both plausible — the argument is close to two tracked
    repos, or it is spelled like a real, different project (`neovide` next to `neovim`).
    One question, naming the candidates.
- **It is nothing tracked** → it is a new repo; go to step 0b.

Never silently create a second profile for something already tracked under another
spelling: that splits the history and restarts the window from zero.

### 0b. Onboard a new repo (create its memory and logs)

Pin down which upstream is meant before writing anything:
1. An `owner/repo` or URL is explicit — confirm it exists (`gh api repos/<owner>/<repo>`).
2. A bare name — first look for it among the inputs in `~/nix_config/flake.lock` (and
   `danvim/flake.lock`): a repo the user pins is almost certainly the one they mean.
3. Otherwise search (`gh search repos <name> --sort stars --limit 5`). Take a result
   only when it clearly dominates and matches the name; with real contenders, ask.
4. If nothing exists under that name, say so and ask what was meant. Do not create a
   memory for a repo that cannot be found.

Then learn enough to write the profile:
- **Upstream** — default branch; where user-facing news is published. Look, in this
  order, for a news/changelog file the project maintains, release notes with real
  bodies, a "what's new" page in its docs; failing all of those, the commit log read by
  subject prefix. Note which files define the surface a config can touch (an example
  config, an options module, a CLI command table).
- **Local setup** — `grep -rn -i <name> ~/nix_config` (skip `flake.lock`) to find where
  the user configures or calls it; how it is pinned (a flake input, a nixpkgs package,
  something else) and how to read the pinned and the running version.
- **Fragile points** — anywhere the setup reaches past the project's documented
  surface: patches, private APIs, names matched by string, comments explaining a
  workaround.

Write `<skill-dir>/repos/<slug>/profile.md` with the headings the shipped profiles use
(read `repos/neovim/profile.md` as the model):

```markdown
---
slug: <short lowercase name>
upstream: <owner/repo>
host: github
branch: <default branch>
aliases: [<other names the user might type>]
---
# <Name>
<what it is and how the user uses it>
## News sources
## Local setup
## Pin
## Fragile points
## Verifying at the pin
## Report specifics
## Applying
```

Leave a section short rather than guessing: "not used in ~/nix_config" is a valid
*Local setup*, and then the report is news only (no impact table, nothing to apply).
Create `reports/`, and tell the user in a line or two what was recorded — upstream,
news source, where the local setup was found — so a wrong guess is caught now rather
than three reports later. Then continue with step 1 as a cold start.

### 1. Read the memory and the previous state

Read `profile.md`, `notes.md` if present, and `state.json`:

```json
{ "last_run_utc": "2026-06-30T22:43:15Z", "last_commit": "abc1234" }
```

- If `state.json` **does not exist** (first run), this is a cold start: use the **last
  30 days** as the window, and say so in the report.
- If it **exists**, the window is from `last_commit` up to the current upstream HEAD of
  the profile's branch.

### 2. Fetch upstream changes

Use the sources the profile's *News sources* section names. Use the host's API — do
**not** clone. Prefer `gh api` (authenticated, so no anonymous rate limit); fall back to
WebFetch on the same URLs.

1. Current HEAD sha, date and subject: `gh api repos/<upstream>/commits/<branch>`
2. The profile's primary news source (a news file, release notes, …).
3. Commits and changed files in the window:
   `gh api repos/<upstream>/compare/<last_commit>...<branch>`
   (on a cold start, skip the compare and rely on the news source + the 30-day window).

Be resilient: if the compare is too large or rate-limited, fall back as the profile
says and note the limitation in the report.

### 3. Read the user's setup

Survey what the profile's *Local setup* lists, so relevance can be judged against what
the user actually runs. Find the rest rather than trusting the list.

**Always read the pin** (the profile's *Pin* section). Report how far the pin is behind
upstream, and whether what is running is older than the pin. These numbers drive step 7
— a feature upstream but not at the pinned rev **cannot be adopted yet**.

**Also check the fragile points** the profile lists. They break without a changelog
entry, and an upstream change that makes one unnecessary is a high-value [ADOPT].

### 4. Write the report

Write `<skill-dir>/repos/<slug>/reports/<slug>-news-<YYYY-MM-DD>.md` (`date +%F`; add
`-HHMM` if one already exists for today). Structure, with the profile's *Report
specifics* supplying the tags, section titles and any extra sections:

```markdown
# <Name> News Update — <date>

**Window:** <last run date / "cold start (30d)"> → <upstream HEAD short-sha> (<HEAD date>)
**Upstream HEAD:** <sha> — <commit subject>

## TL;DR
- 2–5 bullets: the headline changes that matter for *this* setup.

## New / Notable Upstream Features
For each: what it is, and a **Relevance** line with one of the profile's tags.

### <feature name>
...

## Impact on <the user's setup>
| Area / file | Change upstream | What to do |
|---|---|---|

### Could become obsolete
- `<plugin / setting / workaround>` — superseded by `<native feature>` (verify before removing).

### Breaking / needs attention
- `<api or key>` deprecated/renamed → use `<replacement>`. Affects `<file:line>`.

## Ready to apply
Changes that are safe to make **right now**, i.e. verified present at the pinned rev
(see step 4b). Each one gets a before/after snippet and the exact `file:line`, and a
line saying how it was verified at the pinned rev `<sha>`.

## Blocked on a pin bump
- `<change>` — upstream (`<sha>`) but not at pinned `<sha>`.

## Suggested next steps
- Concrete, ordered actions, cheapest first.

## Sources
- News sections / release tags, compare URL, key commit shas.
```

Keep it specific: cite actual file paths and lines in the user's setup and actual
commit shas, release tags or news headings. Don't invent features — only report what's
in the fetched sources. Flag removal suggestions as "verify before removing". If the
window holds nothing user-facing, say so rather than padding.

### 4b. Verify candidates against the *pinned* rev

Before anything lands in "Ready to apply", prove it exists at the pinned rev — **not**
merely upstream or in a release note. Upstream is where the news is; the pin is what
the user actually runs. The profile's *Verifying at the pin* section has the recipes;
the two questions are always the same:

- **Is the change an ancestor of the pin?** If it appears among the commits
  `compare/<pinned_rev>...<branch>` lists, the pin does not have it → "Blocked on a pin
  bump".
- **Does it have the shape the edit assumes?** Read the real definition at the pinned
  rev — the signature, the config key's table and type, the option's name — rather than
  assuming it from the announcement. Things are often reshaped between the first commit
  and the release, and an edit written from the blurb alone fails quietly.

### 5. Update state

After the report is written, overwrite `state.json` with the new HEAD sha and the
current UTC time (`date -u +%Y-%m-%dT%H:%M:%SZ`), plus any extra field the profile
keeps:

```json
{ "last_run_utc": "<now>", "last_commit": "<upstream HEAD sha>" }
```

If the run taught something durable about *how to do this for this repo* — a better
news source, a path that moved, a check that was misleading — append it, dated, to
`notes.md`. Findings about the repo's news belong in the report, not there.

### 6. Report to the user

Tell the user the report path and give the TL;DR inline. Note the pin caveat: say how
far behind upstream the pin is, whether what is running is behind the pin, and which of
the window's changes each already includes.

Then close with the offer: list what's under "Ready to apply" in one line each and ask
whether to apply them. If the list is empty, say so plainly instead of inventing work.

### 7. Apply (only on a yes)

This is the second punch. It runs **only** when the user agrees, and it only ever
touches what "Ready to apply" listed — no opportunistic cleanups of unrelated code you
noticed along the way.

Rules:
- **Never edit before the report exists.** The report is the justification; if the user
  asks to apply mid-research, finish and write the report first.
- **Never apply a "Blocked on a pin bump" item.** If the user wants those, the ordered
  path is: bump the pin (the profile says how) → re-run step 4b against the new pin →
  then apply. A pin bump is itself a change to the user's repo, so ask before running
  it too.
- **Re-verify at edit time**, don't trust the report blindly if the pin moved since it
  was written. Redo the step 4b check for each item being applied.
- Follow the profile's *Applying* section for style and for anything repo-specific.
- Don't rebuild, switch or `git commit` unless asked. Say plainly what changed and what
  is left to verify by hand.

After applying, list each edited `file:line`, what a smoke test would be, and how the
edit goes live (the profile says: most of this setup is Nix-managed, so an edit is
rarely live until a rebuild).

## Notes
- Punch 1 (steps 1–6) is **read-only** toward the user's config; the only things it
  writes are under `<skill-dir>/repos/<slug>/`. Punch 2 (step 7) edits the config, but
  only with an explicit yes and only within the report's "Ready to apply" list.
- Always update `state.json` last, only after a report is successfully written, so a
  failed run doesn't advance the window. Applying edits does **not** touch `state.json`.
- One repo per run. Asked for several, run them one after another, each with its own
  report.
