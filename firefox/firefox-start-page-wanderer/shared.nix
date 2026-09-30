# Values the start page, its service and ../vimium.nix must agree on. Plain
# data, no `pkgs`; paths are relative to $HOME.

let
  port = 47818;
in
{
  inherit port;

  # 127.0.0.1, not localhost: the service checks the Host header against this
  # exact string (a DNS-rebinding guard).
  url = "http://127.0.0.1:${toString port}/";

  # `alias: url description`, %s = the query. sgn and sg have no %s (sg's
  # context is also truncated), so they just open the URL; fixing them changes
  # what the keys do.
  searchAliases = [
    "w: https://www.wikipedia.org/w/index.php?title=Special:Search&search=%s Wikipedia"
    "gh: https://github.com/%s GitHub"
    "eet: https://www.etymonline.com/search?q=%s English etymology"
    "ym: https://music.youtube.com/search?q=%s Youtube Music"
    "syn: https://www.freethesaurus.com/%s Synonyms (Thesaurus)"
    "pydoc: https://pytorch.org/docs/stable/search.html?q=%s&check_keywords=yes&area=default# Pytorch documentation"
    "y: https://www.youtube.com/results?search_query=%s Youtube"
    "gm: https://www.google.com/maps?q=%s Google maps"
    "gs: https://scholar.google.com/scholar?hl=en&as_sdt=0%2C5&q=%s&btnG= Google Scholar"
    "gtf: https://translate.google.com/?sl=auto&tl=fr&text=%s&op=translate Google Translate English -> French"
    "gte: https://translate.google.com/?sl=fr&tl=en&text=%s&op=translate Google Translate French -> English"
    "fc: https://www.frenchconjugation.com/%s.html French conjugaison"
    "d: https://duckduckgo.com/?q=%s DuckDuckGo"
    "r: https://www.reddit.com/r/%s Reddit"
    "ji: https://meet.jit.si/%s Jitsi"
    "sgn: https://sourcegraph.com/search?q=context:global+lang:nix+ Source graph nix"
    "sg: https://sourcegraph.com/search?q=context:globa Source graph"
    "manp: https://helpmanual.io/man1/%s man pages"
    "archw: https://wiki.archlinux.org/index.php/%s Arch Wiki"
    "da: https://dart.platform.research.sony/en?q=%s Dart search"
    "nxs: https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=%s Nix search"
    "saicode: https://github.com/search?q=repo%3ASonyResearch%2Fsai%20%s&type=code SAI code search"
  ];

  # For queries without an alias; also Vimium's `.` and Firefox's default.
  defaultSearchUrl = "https://duckduckgo.com/?q=";

  # The `code` panel's repos: one `git status` a minute, never a fetch.
  repos = [
    "nix_config"
    "nix_config/danvim"
  ];

  # For the `machine` panel: ./result vs /run/current-system, flake.lock age.
  nixConfigDir = "nix_config";

  # The `today` panel's checklist, created on first run. Lines other than
  # `- [ ] `/`- [x] ` items are left untouched.
  todoFile = "notes/todo.md";

  # Drives the fog and tint. Fixed; noctalia auto-locates on its own.
  weather = {
    place = "New York";
    latitude = 40.7128;
    longitude = -74.006;
  };

  # The personal account; `gh auth token --user` picks it over the work one.
  githubUser = "Danielhp95";
}
