// Turning what you type in the search box into a URL, using the same alias
// list Vimium's `o` uses (../shared.nix -> assets/aliases.json).
//
// Pure on purpose: search.test.js runs this under `node --test` during the nix
// build, against the real generated aliases.json. There is no second copy of
// these rules anywhere — the service never parses a query.

/** Fallback engine, matching Vimium's `searchUrl` and Firefox's default. */
export const DEFAULT_SEARCH = "https://duckduckgo.com/?q=";

/**
 * Parse Vimium's `alias: url description` lines.
 * Unparseable lines are skipped rather than throwing: the list is
 * hand-maintained and one bad line should not empty the whole cheat sheet.
 */
export function parseAliases(lines) {
  const out = new Map();
  for (const line of lines) {
    const m = /^\s*([^:\s]+):\s*(\S+)\s*(.*?)\s*$/.exec(line);
    if (m) out.set(m[1], { alias: m[1], url: m[2], description: m[3] });
  }
  return out;
}

/**
 * @returns the URL to navigate to, or null when there is nothing to search.
 *
 * Rules, in order:
 *   ""                  -> null
 *   "https://…"         -> itself, so pasting a URL works
 *   "<alias> <query>"   -> the alias URL with %s replaced
 *   "<alias>"           -> the alias URL with %s replaced by nothing
 *   an alias with no %s -> opened as-is (Vimium does the same; `sg`/`sgn`)
 *   anything else       -> DuckDuckGo
 */
export function expandSearch(input, aliases, defaultSearch = DEFAULT_SEARCH) {
  const query = input.trim();
  if (!query) return null;
  if (/^https?:\/\//i.test(query)) return query;

  const split = query.search(/\s/);
  const head = split === -1 ? query : query.slice(0, split);
  const rest = split === -1 ? "" : query.slice(split).trim();

  const hit = aliases.get(head);
  if (!hit) return defaultSearch + encodeURIComponent(query);
  if (!hit.url.includes("%s")) return hit.url;
  return hit.url.split("%s").join(encodeURIComponent(rest));
}
