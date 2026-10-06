// Search-box input -> URL, with the alias list Vimium's `o` uses (../shared.nix
// -> assets/aliases.json). Pure, so search.test.js runs it in the nix build.

/** Fallback engine, matching Vimium's `searchUrl` and Firefox's default. */
export const DEFAULT_SEARCH = "https://duckduckgo.com/?q=";

/** Parse `alias: url description` lines; bad lines are skipped, not fatal. */
export function parseAliases(lines) {
  const out = new Map();
  for (const line of lines) {
    const m = /^\s*([^:\s]+):\s*(\S+)\s*(.*?)\s*$/.exec(line);
    if (m) out.set(m[1], { alias: m[1], url: m[2], description: m[3] });
  }
  return out;
}

/**
 * The URL for a query, or null if empty. URLs pass through; `<alias> <query>`
 * fills the alias's %s (an alias without %s opens as-is, as in Vimium);
 * anything else goes to defaultSearch.
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
