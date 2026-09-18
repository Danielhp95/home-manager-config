// The start page's only script: clock, polling, rendering, search, todo.
//
// Two rules shape all of it:
//   1. Nothing here listens for a keypress. Vimium owns the keyboard, and the
//      only reachable controls are real <a>, <input> and <button> elements so
//      that `f` hints land on them.
//   2. Text from the todo file, from git and from GitHub is only ever written
//      with textContent. Nothing builds HTML out of it.

import { expandSearch, parseAliases } from "./search.js";

const POLL_MS = 30_000;

// ---------- tiny DOM helpers ----------------------------------------------

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === null || value === false) continue;
    if (key === "class") node.className = value;
    else if (key === "text") node.textContent = value;
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined) continue;
    node.append(child);
  }
  return node;
}

function replace(id, ...children) {
  const host = document.getElementById(id);
  host.replaceChildren(...children.flat().filter(Boolean));
}

/** The panels' house style: values separated by a middle dot. */
function joined(nodes, separator = " · ") {
  return nodes
    .filter(Boolean)
    .flatMap((node, i) => (i ? [document.createTextNode(separator), node] : [node]));
}

const pad = (n) => String(n).padStart(2, "0");
const fmtClock = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;

/** Wall-clock time at the weather location, which may not be this machine's
 *  timezone — the laptop travels, the painted coastline does not. */
function fmtAtOffset(epochSeconds, offsetSeconds) {
  const shifted = new Date((epochSeconds + offsetSeconds) * 1000);
  return `${pad(shifted.getUTCHours())}:${pad(shifted.getUTCMinutes())}`;
}

function fmtAge(seconds) {
  const s = Math.max(0, Math.round(seconds));
  if (s < 90) return `${s}s`;
  const m = Math.round(s / 60);
  if (m < 90) return `${m}m`;
  const h = Math.round(m / 60);
  if (h < 48) return `${h}h`;
  return `${Math.round(h / 24)}d`;
}

// ---------- clock ----------------------------------------------------------

function tickClock() {
  const now = new Date();
  document.getElementById("clock").textContent = fmtClock(now);
  document.getElementById("date").textContent = now.toLocaleDateString(
    "en-GB",
    { weekday: "long", day: "numeric", month: "long" },
  );
}

// ---------- section status (stale / error) ---------------------------------

function renderStatus(id, section, now) {
  const host = document.getElementById(id);
  if (!host) return;
  host.className = "status";
  if (!section) {
    host.textContent = "";
    return;
  }
  if (section.error) {
    host.classList.add("error");
    host.textContent = `error: ${section.error}`;
    return;
  }
  const age = now - (section.fetchedAt ?? now);
  host.textContent = age > (section.staleAfter ?? Infinity) ? `stale · ${fmtAge(age)}` : "";
}

// ---------- sky: the line, and the weather on the canvas -------------------

function renderSky(section, now) {
  const sky = section?.data;
  if (!sky) return;

  const next = (sky.sun ?? [])
    .flatMap((day) => [
      { kind: "sunrise", at: day.sunrise },
      { kind: "sunset", at: day.sunset },
    ])
    .filter((e) => e.at > now)
    .sort((a, b) => a.at - b.at)[0];

  const parts = [
    el("span", { text: sky.place }),
    el("span", { text: `${Math.round(sky.temperatureC)}°` }),
    el("span", { class: "weather", text: sky.label }),
  ];
  if (next) {
    const offset = sky.utcOffsetSeconds ?? 0;
    const elsewhere = offset * 1000 !== -new Date().getTimezoneOffset() * 60_000;
    parts.push(
      el("span", {
        class: "dim",
        text: `${next.kind} ${fmtAtOffset(next.at, offset)}${elsewhere ? ` in ${sky.place}` : ""}`,
        title: elsewhere
          ? `${fmtClock(new Date(next.at * 1000))} on this machine's clock`
          : "",
      }),
    );
  }
  replace("sky", joined(parts));

  paintWeather(sky, now, next);
}

function paintWeather(sky, now, next) {
  const root = document.documentElement.style;
  const cloud = (sky.cloudCover ?? 50) / 100;
  const visibility = sky.visibilityM ?? 20000;
  const haze = visibility < 8000 ? (1 - visibility / 8000) * 0.45 : 0;
  const fogBoost = sky.isFog ? 0.3 : 0;

  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  root.setProperty("--fog-low", clamp(0.18 + cloud * 0.5 + haze + fogBoost, 0.1, 1).toFixed(2));
  root.setProperty("--fog-high", clamp(0.1 + cloud * 0.35 + fogBoost * 0.8, 0.05, 0.8).toFixed(2));

  // Sun phase: how close we are to the nearest sunrise/sunset, and whether
  // the sun is up at all.
  const events = (sky.sun ?? []).flatMap((d) => [d.sunrise, d.sunset]).sort((a, b) => a - b);
  const nearest = events.length
    ? events.reduce((best, t) => (Math.abs(t - now) < Math.abs(best - now) ? t : best))
    : null;
  const today = sky.sun?.[0];
  const isDay = today ? now >= today.sunrise && now <= today.sunset : true;

  let glow = 0;
  if (nearest !== null) {
    const closeness = 1 - Math.min(1, Math.abs(nearest - now) / 3600);
    glow = 0.45 * closeness + (isDay ? 0.06 : 0);
  }
  root.setProperty("--glow-strength", glow.toFixed(2));
  root.setProperty(
    "--glow-colour",
    next?.kind === "sunrise" && !isDay
      ? "var(--ember-accent)"
      : "var(--ember-accent-bright)",
  );
  root.setProperty("--art-brightness", (isDay ? 0.88 : 0.55).toFixed(2));
}

// ---------- machine --------------------------------------------------------

function renderMachine(section) {
  const m = section?.data;
  if (!m) return;

  const system = [];
  if (m.switchPending) {
    system.push(el("span", { class: "warn", text: "● switch pending" }));
    if (m.builtAt) {
      system.push(
        el("span", { class: "muted", text: `built ${fmtAge(Date.now() / 1000 - m.builtAt)} ago` }),
      );
    }
  }
  if (m.rebootPending) {
    system.push(el("span", { class: "warn", text: "● reboot pending" }));
  }
  if (!system.length) {
    system.push(el("span", { class: "ok", text: "✓ system current" }));
  }

  const bits = [];
  if (m.flakeLockModified) {
    bits.push(`flake.lock ${fmtAge(Date.now() / 1000 - m.flakeLockModified)}`);
  }
  if (m.disk) bits.push(`disk ${m.disk.percent}%`);
  if (m.battery) {
    const charging = m.battery.status === "Charging" ? "+" : "";
    bits.push(`bat ${charging}${m.battery.capacity}%`);
  }

  const diskClass = !m.disk ? "dim" : m.disk.percent >= 95 ? "alert" : m.disk.percent >= 85 ? "warn" : "dim";

  const ollama = m.ollama?.running
    ? m.ollama.models?.length
      ? el(
          "p",
          {},
          document.createTextNode("ollama "),
          el("span", { class: "accent", text: m.ollama.models.map((x) => x.name).join(", ") }),
        )
      : el("p", { class: "dim", text: "ollama idle" })
    : el("p", { class: "dim", text: "ollama off" });

  replace(
    "machine-body",
    el("p", {}, joined(system)),
    // The disk number carries a glyph when it is in the red, because palette
    // error and accent are near-equiluminant (see ../../palette.nix).
    el(
      "p",
      { class: diskClass },
      document.createTextNode(
        `${m.disk && m.disk.percent >= 95 ? "! " : ""}${bits.join(" · ")}`,
      ),
    ),
    ollama,
  );
}

// ---------- code -----------------------------------------------------------

function repoRow(repo) {
  const label = repo.webUrl
    ? el("a", { href: repo.webUrl, text: repo.name })
    : el("span", { text: repo.name });

  if (repo.error) {
    return el("p", { class: "row" }, label, el("span", { class: "alert", text: repo.error }));
  }

  const bits = [];
  if (repo.modified) bits.push({ text: `±${repo.modified}`, class: "warn" });
  if (repo.untracked) bits.push({ text: `?${repo.untracked}`, class: "warn" });
  if (repo.ahead) bits.push({ text: `↑${repo.ahead}`, class: "accent" });
  if (repo.behind) bits.push({ text: `↓${repo.behind}`, class: "accent" });
  if (!bits.length) bits.push({ text: "clean", class: "ok" });
  if (repo.detached) bits.push({ text: "detached", class: "warn" });

  return el(
    "p",
    { class: "row" },
    label,
    ...bits.map((b) => el("span", { class: b.class, text: b.text })),
  );
}

function prList(prs) {
  return el(
    "ul",
    { class: "pr-list" },
    ...prs.map((pr) =>
      el(
        "li",
        {},
        el("a", {
          href: pr.url,
          text: `${pr.repo}#${pr.number} ${pr.title}`,
          title: pr.title,
        }),
        pr.draft ? el("span", { class: "muted", text: " draft" }) : null,
      ),
    ),
  );
}

function renderCode(section) {
  const code = section?.data;
  if (!code) return;

  const children = (code.repos ?? []).map(repoRow);

  const gh = code.github;
  if (gh?.error) {
    children.push(el("p", { class: "sub", text: "github" }), el("p", { class: "alert", text: gh.error }));
  } else if (gh) {
    children.push(el("p", { class: "sub", text: "waiting on you" }));
    children.push(
      gh.review?.length ? prList(gh.review) : el("p", { class: "dim", text: "no reviews" }),
    );
    children.push(el("p", { class: "sub", text: "your prs" }));
    children.push(
      gh.mine?.length ? prList(gh.mine) : el("p", { class: "dim", text: "none open" }),
    );
  }

  replace("code-body", children);
}

// ---------- today ----------------------------------------------------------

let todoVersion = null;

function renderTodo(section) {
  const todo = section?.data;
  if (!todo) return;
  todoVersion = todo.version;

  const items = todo.items ?? [];
  const rows = items.map((item) =>
    el(
      "li",
      { class: item.done ? "done" : null },
      el("button", {
        type: "button",
        class: "check",
        "data-line": String(item.line),
        "aria-pressed": item.done ? "true" : "false",
        text: item.done ? "☑" : "☐",
        title: item.done ? "mark not done" : "mark done",
      }),
      el("span", { class: "text", text: item.text }),
    ),
  );

  replace("todo-list", rows.length ? rows : el("li", { class: "dim", text: "nothing today" }));
  document.getElementById("todo-clear").hidden = !items.some((item) => item.done);
}

function flash(message) {
  const node = document.getElementById("todo-flash");
  node.textContent = message;
  node.hidden = !message;
  if (message) setTimeout(() => flash(""), 6000);
}

async function todoAction(action, body = {}) {
  const res = await fetch(`/api/todo/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...body, version: todoVersion }),
  });
  const payload = await res.json().catch(() => null);

  if (res.status === 409) {
    renderTodo(payload?.todo);
    flash("file changed on disk, reloaded");
    return false;
  }
  if (!res.ok) {
    flash(payload?.error ? `error: ${payload.error}` : `error: HTTP ${res.status}`);
    return false;
  }
  renderTodo(payload?.todo);
  return true;
}

// ---------- polling --------------------------------------------------------

async function poll() {
  if (document.visibilityState === "hidden") return;
  let state;
  try {
    state = await (await fetch("/api/state", { cache: "no-store" })).json();
  } catch {
    // Say so on every panel, not just one: the panels keep their last values,
    // and without this they would look current while the backend is gone.
    for (const id of ["machine-status", "code-status", "todo-status"]) {
      renderStatus(id, { error: "backend unreachable" }, 0);
    }
    return;
  }
  const now = state.serverTime ?? Date.now() / 1000;

  renderSky(state.sky, now);
  renderMachine(state.machine);
  renderCode(state.code);
  renderTodo(state.todo);

  renderStatus("machine-status", state.machine, now);
  renderStatus("code-status", state.code, now);
  renderStatus("todo-status", state.todo, now);
}

// ---------- wiring ---------------------------------------------------------

async function main() {
  tickClock();
  setInterval(tickClock, 1000);

  // The catch belongs on the fetch, not on .json(): the service restarts on
  // every switch, and a rejected fetch here used to abort main() and leave a
  // page that ticks its clock but whose search box and panels do nothing.
  const aliases = parseAliases(
    await fetch("/assets/aliases.json")
      .then((response) => response.json())
      .catch(() => []),
  );

  replace(
    "alias-list",
    [...aliases.values()].map((a) =>
      el(
        "li",
        {},
        el("span", { class: "alias", text: a.alias }),
        document.createTextNode(` ${a.description}`),
      ),
    ),
  );

  document.getElementById("search-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const target = expandSearch(document.getElementById("search-input").value, aliases);
    if (target) window.location.href = target;
  });

  document.getElementById("todo-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const input = document.getElementById("todo-input");
    const text = input.value.trim();
    if (!text) return;
    if (await todoAction("add", { text })) input.value = "";
  });

  document.getElementById("todo-list").addEventListener("click", (event) => {
    const button = event.target.closest("button.check");
    if (button) todoAction("toggle", { line: Number(button.dataset.line) });
  });

  document.getElementById("todo-clear").addEventListener("click", () => {
    todoAction("clear-done");
  });

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") poll();
  });

  await poll();
  setInterval(poll, POLL_MS);
}

main();
