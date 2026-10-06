---
slug: neovim
upstream: neovim/neovim
host: github
branch: master
aliases: [nvim, neovim-nightly, danvim]
---

# Neovim

The editor. The user runs a nightly build with their own config, `~/nix_config/danvim`,
a **nixCats** flake, so both the Neovim version and the config are pinned through Nix.

## News sources

Neovim documents every notable user-facing change in `runtime/doc/news.txt` on master.
That file is the primary source.

1. `https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/news.txt` —
   organized newest-first, with `NEW FEATURES`, `CHANGES`, `DEPRECATIONS`, etc. per
   release. Focus on the unreleased / most recent section(s) that fall inside the window.
2. The compare (`<last_commit>...master`) for finer detail. Prioritize commits with
   `feat`, `feat!`, `vim-patch`, and anything under `runtime/lua`, `runtime/doc`, LSP,
   treesitter, diagnostics, and the Lua API.

If the compare is too large or rate-limited, fall back to `news.txt` alone and note the
limitation in the report. If `news.txt` shows the same section as the previous report,
say "no major user-facing changes since last run" rather than padding.

## Local setup

Survey `~/nix_config/danvim`:
- `lua/danvim/options.lua`, `keybindings.lua`, `builtin_plugins.lua`, `aucmds.lua`
- `lua/danvim/plugins/*.lua` — the installed plugins (lsp, treesitter, blink, snacks,
  telescope, noice, etc.)
- `flake.nix` / `packages` — the nixCats definition.

A change is **relevant** if it: replaces a plugin the user has, adds a native feature the
user currently gets from a plugin, deprecates/breaks an API the config calls, or changes
a default the config overrides.

## Pin

The pin lives in `~/nix_config/danvim/flake.lock`. The nodes that matter are `neovim-src`
(the actual Neovim source), `neovim-nightly-overlay`, and `nixpkgs`:

```bash
cd ~/nix_config/danvim && python3 -c "
import json,datetime
d=json.load(open('flake.lock'))['nodes']
for k in ('neovim-src','neovim-nightly-overlay','nixpkgs','stable'):
    n=d.get(k,{}).get('locked',{})
    print(k, n.get('rev'), datetime.datetime.fromtimestamp(n['lastModified'], datetime.UTC).isoformat() if 'lastModified' in n else '')
"
```

`~/nix_config` pulls danvim in as a `path:` flake input pinned by hash, so the installed
`nvim` can lag danvim's own lock until `nix flake update danvim` there plus a rebuild.

## Fragile points

Private-module usage. Grep the config for `require("vim%.` and `vim%._` to find reaches
into `vim._core`, `vim.treesitter._select`, and similar underscore namespaces. They can
be renamed without notice, and when upstream promotes one to a public API, that is a
high-value [ADOPT] item.

## Verifying at the pin

**Is the fix an ancestor of the pin?** Read the commits the pin is missing:
`https://api.github.com/repos/neovim/neovim/compare/<pinned_rev>...<master_sha>`.
If the commit you care about appears in that list, the pin does **not** have it.

**Does the API exist at the pin?** Fetch the runtime file at the pinned sha and read the
actual signature and `@param` annotations:
`https://raw.githubusercontent.com/neovim/neovim/<pinned_rev>/runtime/lua/vim/<file>.lua`

A promoted-to-public API is often *reshaped* on the way out — e.g.
`vim.treesitter._select.select_child(count)` / `select_parent(count)` / `select_prev` /
`select_next` became a single `vim.treesitter.select(target, count)` with
`target: 'parent'|'child'|'next'|'prev'|'extend_next'|'extend_prev'`. Writing the edit
from the news blurb alone would have produced four calls to a function that doesn't take
those arguments.

## Report specifics

- Relevance tags: [ADOPT] native feature worth enabling · [REPLACES <plugin>] ·
  [BREAKING] · [NEUTRAL].
- Impact section title: "Impact on danvim config"; rows keyed by file, e.g.
  `plugins/lsp.lua`. Snippets are `lua`.
- "Blocked on a pin bump" items say: re-check after `nix flake update` in danvim.

## Applying

- A pin bump is `nix flake update` in `~/nix_config/danvim` — ask before running it.
- Match the surrounding style: this config uses **tabs**, and keeps one `vim.keymap.set`
  call per binding rather than collapsing them.
- No edit is live on the next launch: the installed `nvim` is danvim's nixCats package
  with `wrapRc = true`, so it runs a store copy of the config. Any edit, Lua included,
  reaches the installed `nvim` only after `nix flake update danvim` in `~/nix_config`
  plus a rebuild; a new file must also be `git add`ed in danvim first, or the flake
  source drops it.
- To smoke-test before that, point nixCats at the repo instead of the store copy:

```sh
VIMINIT='lua local nc=require("nixCats") local store=nc.configDir local repo="/home/dani/nix_config/danvim" vim.opt.runtimepath:remove(store) vim.opt.runtimepath:remove(store.."/after") vim.opt.runtimepath:prepend(repo) vim.opt.runtimepath:append(repo.."/after") nc.configDir=repo nixCats.init_main()' nvim
```
