# firefox-start-page-wanderer: design

Date: 2026-09-15 · Status: design approved section by section, awaiting spec review

A Firefox start/new-tab page built on Friedrich's *Wanderer above the Sea of
Fog* that also works as a live dashboard, fully usable through Vimium. It is
built by nix, served by a local user service, and themed with `palette.nix`.

## 1. Decisions (from the brainstorming Q&A)

| Topic | Decision |
|---|---|
| Purpose | Art plus a live dashboard, inspired by *Wanderer above the Sea of Fog* |
| Art rendering | The real painting (public domain), Ember-graded. Chosen over a vector homage and an ASCII etching |
| Composition | **Gallery wall**: the whole uncropped canvas on the right, fading into a graphite dashboard column on the left |
| Live data | Sky (weather + sun), machine state, code (git + GitHub), todo |
| Calendar | Out of scope for now |
| Word of the day | Out of scope for now |
| Todo | Editable on the page, backed by a markdown checklist file |
| GitHub | Personal account `Danielhp95` only |
| Architecture | Approach A: one stdlib-only Python user service plus a nix-built static page |
| Delivery | Two stages (§9) |
| Name | `firefox-start-page-wanderer` |
| Location | All code under `firefox/` in this repo. Nothing is committed (§10) |

Out of scope, and deliberately so: calendar, word of the day, the work GitHub
account, auto-location, restyling Vimium hints to Ember, and a generated
widescreen outpaint of the painting (possible later as a drop-in image swap).

## 2. Files

```
firefox/
  default.nix                          imports ./firefox-start-page-wanderer; NTO add-on,
                                       its settings, startup prefs (§7)
  vimium.nix                           searchEngines now read from shared.nix (§5)
  firefox-start-page-wanderer/
    default.nix                        systemd user service (imports package.nix)
    package.nix                        page + service derivations, buildable on their
                                       own without evaluating all of Home Manager
    shared.nix                         port, url, search aliases, repo list, todo path,
                                       weather coordinates (plain attrset, imported like
                                       ../../palette.nix)
    art.nix                            fetchurl painting → ImageMagick Ember grade
    service/
      firefox-start-page-wanderer.py   HTTP server, collectors, todo store
      test_*.py                        unittest suites run in checkPhase (§8)
      fixtures/                        captured outputs for parser tests
    page/
      index.html
      style.css                        palette injected as custom properties by nix
      app.js                           rendering, polling, todo actions
      search.js                        expandSearch(input, aliases): pure, ES module
      search.test.js                   node --test suite for search.js
```

`shared.nix` values (initial):

- `port = 47818;` `url = "http://127.0.0.1:47818/";`
- `searchAliases`: the 22 entries currently in `firefox/vimium.nix`, moved
  verbatim, including the malformed `sg` / `sgn` (see that file's comment).
- `repos = [ "/home/dani/nix_config" "/home/dani/nix_config/danvim" ];`
- `todoFile = "/home/dani/notes/todo.md";`
- `weather = { place = "A Coruña"; latitude = 43.37; longitude = -8.40; };`
  (matches noctalia's `location.address = "coruna"`)

## 3. Build (nix)

- **Art (`art.nix`)**: `fetchurl` of
  `https://upload.wikimedia.org/wikipedia/commons/b/b9/Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg`
  (2327×2980), `hash = "sha256-4D5bjBnMmShZJln5iDTlaNPeEak+Axq4CT9cPvEX8h0="`.
  A `runCommand` using ImageMagick resizes it to 1800 px tall, converts to
  gray, applies `-contrast-stretch 1%x0.5%`, then a 5-stop gradient-map CLUT:
  `#0c0b0a → #221c19 → #4a3b33 → #8a7061 → #c8ab94`. This is exactly the grade
  approved in the mockup. Output: `wanderer-ember.jpg`. No image is stored in git.
- **Font**: the Cormorant Garamond regular and italic files are copied out of
  `pkgs.cormorant` (4.002) into the page's assets and loaded with
  `@font-face`, so the page doesn't depend on fontconfig. Fallback stack:
  `Georgia, serif`. Data text uses `JetBrainsMono Nerd Font`, already installed.
- **Page**: a derivation that copies `page/`, writes `palette.css` (`:root {
  --ember-*: … }` from `palette.nix`, same technique as `userChrome.css`),
  writes `aliases.json` from `shared.nix`, and adds the art and fonts.
- **Service**: `python3` (stdlib only), with `checkPhase` running
  `python -m unittest` over `service/`. The page's store path and a generated
  config JSON (port, repos, todo path, weather, GitHub user) are passed as
  arguments.

## 4. Service

systemd user unit `firefox-start-page-wanderer.service`:
`WantedBy=default.target`, `Restart=always`. It needs no Wayland, so it is
kept off `graphical-session.target`, which Hyprland stops and starts (see
memory: graphical-session.target dance).

### 4.1 HTTP surface

| Method | Path | Purpose |
|---|---|---|
| GET | `/`, `/assets/*` | Static page from the nix store |
| GET | `/api/state` | `{ sky, machine, code, todo }` |
| POST | `/api/todo/toggle` | `{ line, version }` |
| POST | `/api/todo/add` | `{ text, version }` |
| POST | `/api/todo/clear-done` | `{ version }` |

Each section of `/api/state` is `{ data, fetchedAt, error }`. Collectors run
on their own threads and intervals and cache their results. An exception sets
`error` and keeps the last good `data`. A collector failing never takes down
the server.

### 4.2 Collectors

- **sky** (stage 1, every 15 min): Open-Meteo `/v1/forecast` with
  `current=temperature_2m,weather_code,cloud_cover,visibility` and
  `daily=sunrise,sunset`, `timezone=auto`. No API key.
- **machine** (stage 2, every 60 s):
  - switch pending: `readlink ~/nix_config/result` ≠ `readlink
    /run/current-system`. This is a known limit: it only sees builds that leave
    `./result`.
  - reboot pending: `/run/booted-system/{kernel,initrd,kernel-modules}`
    differ from `/run/current-system/…`.
  - flake.lock age: `nodes.nixpkgs.locked.lastModified`.
  - disk: `statvfs("/home")`. Gold at ≥ 85%. `error` colour at ≥ 95%, always
    paired with a glyph (palette.nix rule).
  - battery: `/sys/class/power_supply/BAT*/{capacity,status}`, hidden when absent.
  - ollama: `GET 127.0.0.1:11434/api/ps` returns loaded model names. Connection
    refused shows "off" and is not treated as an error.
- **code** (stage 2):
  - local repos (every 60 s): `git -C <repo> status --porcelain=v2 --branch`
    gives the modified count and ahead/behind as of the last fetch. It never
    fetches. Handles detached HEAD and no upstream. Rows link to the GitHub
    remote when one exists.
  - GitHub (every 5 min): `GH_TOKEN=$(gh auth token --user Danielhp95)` is
    read on each refresh, never stored or logged. `gh search prs --author=@me
    --state=open` and `--review-requested=@me --state=open`, `--json` output,
    up to 5 of each.
- **todo** (stage 2, on request plus re-read on every `/api/state`):
  - File `todoFile`, created empty if missing. Items are lines matching
    `^\s*- \[( |x)\] `. Every other line is preserved byte for byte.
  - `version` = sha256 of the file content the page rendered from. A mismatch
    returns 409, and the page re-fetches and shows "file changed, reloaded".
  - Writes go to a temp file in the same directory, then `rename`.
  - Item text is only ever inserted via `textContent`.

### 4.3 Localhost hardening

- Bind `127.0.0.1` only.
- Reject any request whose `Host` ≠ `127.0.0.1:47818` with 403 (DNS rebinding).
- Never emit CORS headers. Cross-origin pages cannot read `/api/state`.
- Every POST requires `Content-Type: application/json` (415 otherwise). This
  forces a preflight that is never approved. POSTs also require `Origin: http://127.0.0.1:47818` (403 otherwise).

## 5. Page

- **Gallery wall layout (viewport ≥ 1100 px)**: the painting sits right-aligned
  at full height, masked `linear-gradient(to right, transparent, #000 30%)`
  into `--ember-bg`. The left column, top to bottom: clock (Cormorant Garamond),
  italic date, sky line (`A Coruña 17° · haze · sunset 20:31`), search input,
  *today* panel, then *machine* and *code* panels side by side.
- **< 1100 px** (hy3 half-width): the painting moves behind the column with a
  darker scrim, and the panels stack.
- **Living art**: two CSS fog layers drift over the painting.
  - Fog opacity comes from cloud cover and visibility, boosted for weather
    codes 45/48.
  - A glow tint follows sun phase: coral within ~1 h of sunrise or sunset,
    neutral by day, deeper graphite at night.
  - `prefers-reduced-motion` stops the drift.
- **Polling**: `/api/state` every 30 s, re-rendering only sections whose
  `fetchedAt` changed. The clock ticks client-side. A stale or failed section
  shows a dim `stale · 4m` or `error: <reason>` line and is never removed.
- **Search**: first word ∈ aliases → substitute the rest for `%s`. If the URL
  has no `%s`, it is opened as-is, so `sg`/`sgn` keep their current
  behaviour. Otherwise it goes to `https://duckduckgo.com/?q=` (Vimium's
  `searchUrl`). A `<details>` below it lists all aliases.
- **Vimium contract**:
  - No page-level key handlers at all.
  - Every actionable element is a real `<a href>`, `<input>` or `<button>`
    (PR rows, repo rows, todo checkboxes, the aliases `<details>`), so `f`
    hints reach it.
  - Search is the first `<input>` in DOM order (`gi`) and the todo add field
    the second (`2gi`). Neither autofocuses.
  - Links open in the same tab. `F` still gives a new tab.
- **If the service is down**: Firefox shows "Unable to connect". The
  mitigation is `Restart=always` plus collector isolation. There is no
  offline fallback in v1.

## 6. Data shown (reference mock)

The approved mockup is the *Gallery wall* card in the brainstorm session. The
placeholder values used there ("Madrid", model names) are illustrative only.

## 7. Firefox wiring (`firefox/default.nix`)

- Add `new-tab-override` (v19.0.0 in the pinned `firefox-addons` input,
  id `newtaboverride@agenedia.com`) to `extensions.packages`.
- `extensions.settings."newtaboverride@agenedia.com" = { force = true;
  settings = { type = "custom_url"; url = shared.url; focus_website = true; }; };`
  Key names were verified in the XPI's `js/core/defaults.js`. `focus_website`
  opens a new tab and removes the internal one (`js/core/newtab.js`), so
  keyboard focus lands in content.
- Caveat, to be documented in the module header: Home Manager writes
  `browser-extension-data/<id>/storage.js`, which Firefox imports into its
  IndexedDB only on the add-on's first run. Later nix edits to these values
  are ignored until the add-on's data is reset or changed on its options page.
- `browser.startup.homepage = shared.url;` and `browser.startup.page = 1;`
  The latter is the profile's current value, pinned per memory: HM pref
  removal ≠ unset.
- Vimium: no exclusion change (only `127.0.0.1:8888` is excluded). Vimium's
  `t` is expected to go through NTO. Verified in §8.3, not assumed.
- Accepted v1 side effects: the URL bar shows `127.0.0.1:47818` on new tabs;
  each new tab adds a history entry; private windows keep the stock new tab.

## 8. Testing and verification

### 8.1 Build-time unit tests (`checkPhase`)
- todo store: toggle, add, clear-done; non-item lines preserved byte for
  byte; stale version → 409; atomic write (no partial file on simulated failure).
- collector parsers on fixtures: git porcelain v2 (normal, detached, no
  upstream), Open-Meteo JSON, ollama `/api/ps` (and connection refused), gh
  search JSON, battery absent.
- HTTP hardening against a live server on an ephemeral port: wrong Host → 403,
  POST with bad or missing Origin → 403, non-JSON POST → 415, no
  `Access-Control-*` header on any response.
- alias expansion: `node --test page/search.test.js` in the page derivation's
  `checkPhase` (`nodejs` as a check-time input only; nothing ships it). Cases:
  with `%s`, without `%s`, unknown first word → DuckDuckGo, empty input → no-op,
  run against the real generated `aliases.json`. There is one implementation
  only (`search.js`), with no Python mirror.

### 8.2 Pre-switch live check
After `nh os build`, run the built service from its store path on 47818 and
open it in the current Firefox for visual approval (memory: aesthetic changes
need live approval). Take headless Chromium screenshots at 1920 px and 960 px
widths. Exercise `f`, `gi`, `2gi` and `Esc` under Vimium.

### 8.3 Post-switch checklist (user runs the switch; sudo unavailable to Claude)
- [ ] (S1) `systemctl --user status firefox-start-page-wanderer` active; survives a Hyprland restart
- [ ] (S1) Ctrl+T → page, `j`/`f` work without clicking
- [ ] (S1) Vimium `t` → same
- [ ] (S1) Firefox restart → page is the start page; NTO options page shows the URL
- [ ] (S1) hy3 half-width window → stacked layout
- [ ] (S2) ollama stopped → machine panel says "off"
- [ ] (S2) edit todo in nvim, toggle on page → "file changed, reloaded"

## 9. Stages

- **Stage 1**: module skeleton, `shared.nix` (+ vimium.nix reading
  aliases from it), art derivation, page (layout, clock, living art, search),
  service with the `sky` collector and the empty-state panels, Firefox wiring.
  Done when §8.1's HTTP-hardening and alias suites, §8.2, and the (S1) items
  of §8.3 pass.
- **Stage 2**: `machine`, `code` and `todo` collectors plus the todo write
  endpoints and panel UIs. Done when all of §8 passes.

## 10. Repo handling

- Nothing is committed: not the spec, not the code.
- New files must still be `git add`ed (staged, uncommitted). The flake is a
  git repository, so untracked files are invisible to `nh os build`. This is
  the same trap as memory: danvim new files need git add.
- The user's existing uncommitted changes are left untouched.

## 10b. Deviations found while building (2026-09-18)

- **`package.nix` added** (above): it also keeps the derivations away from
  `callPackage`'s argument injection — nixpkgs has a package called `palette`,
  which silently shadowed a defaulted `palette ? import ../../palette.nix`
  argument and failed with "attribute 'hash' missing".
- **`ProtectHome` dropped** from the unit. The service's whole job is reading
  `$HOME`, and `gh` needs a state directory; `ProtectSystem=strict` and the
  cheap flags stay. Verified: `gh auth token --user` still reaches the keyring
  from inside the unit.
- **`sky.utcOffsetSeconds` added.** This machine's timezone is
  America/New_York while the weather location is A Coruña, so the page printed
  A Coruña's 20:38 sunset as "14:38". Sun times now render in the location's
  own timezone, labelled "in A Coruña" when the two differ. The underlying
  mismatch is a question for the user, not a bug.
- **POST bodies are read before rejection.** A rejected write that left its
  body unread poisoned the next request on the same keep-alive connection;
  `test_a_rejected_write_does_not_poison_the_connection` covers it.
- **Verified in a real browser**, not just in tests: a same-origin `fetch`
  POST does carry `Origin`, so the write path works end to end.

## 11. Risks and open points

- **Wikimedia and `fetchurl`**: upload.wikimedia.org may reject the default
  curl User-Agent. If the fetch fails, set `curlOptsList` with a descriptive
  UA that carries no personal contact details.
- **NTO first-run import**: if `storage.js` is not picked up on this existing
  profile, fall back to a one-time manual set on NTO's options page. Document
  it the way Vimium restore is documented.
- **`pkgs.cormorant` family names**: confirm the TTFs inside expose
  "Cormorant Garamond" (vs "Cormorant") when copying them.
- **Weather location** is fixed. It goes wrong on the T16g when travelling
  (pending machine migration). Auto-location is a later addition.
