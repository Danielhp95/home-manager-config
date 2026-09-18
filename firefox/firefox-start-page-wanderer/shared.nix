# Values that the start page, its backend service and the rest of the Firefox
# modules all have to agree on. Plain data, no `pkgs`, imported the same way
# ../../palette.nix is — so ./default.nix (the service), ./package.nix (the
# built page) and ../vimium.nix cannot drift apart.
#
# Paths are relative to $HOME on purpose: ../../home.nix is imported by both
# the `dani` and `dev` users (flake.nix), so an absolute /home/dani would be a
# lie in one of them. ./default.nix prefixes them with
# config.home.homeDirectory.

let
  port = 47818;
in
{
  inherit port;

  # The page's own origin. Spelled with 127.0.0.1 rather than localhost
  # because the service checks the Host header against this exact string (a
  # DNS-rebinding guard), and "localhost" would not match it.
  url = "http://127.0.0.1:${toString port}/";

  # `o`/`O`/`b`/`B` search aliases, shared with Vimium. Format is
  # `alias: url description`, with %s as the query placeholder.
  #
  # Two of these are kept verbatim despite looking wrong, because fixing them
  # silently would change what the keys do:
  #   sgn  has no %s at all — the query lands nowhere
  #   sg   has no %s and its context: value is truncated ("globa")
  # Fix or delete them deliberately, not as a side effect of a port. The start
  # page treats a %s-less alias the same way Vimium does: it just opens the URL.
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

  # Fallback when the first word of a query is not an alias. Same engine as
  # Vimium's `searchUrl` and Firefox's default engine (../default.nix).
  defaultSearchUrl = "https://duckduckgo.com/?q=";

  # Repositories the `code` panel watches. It only reads the working tree — it
  # never fetches — so listing a repo here costs one `git status` a minute.
  repos = [
    "nix_config"
    "nix_config/danvim"
  ];

  # This flake's checkout, for the `machine` panel: ./result versus
  # /run/current-system, and flake.lock's nixpkgs age.
  nixConfigDir = "nix_config";

  # Markdown checklist behind the `today` panel. Created empty on first run.
  # Lines that are not `- [ ] `/`- [x] ` items are preserved untouched, so
  # headings and notes in the same file survive the page editing it.
  todoFile = "notes/todo.md";

  # Weather and the sun that drive the fog and the tint.
  #
  # New York, where this machine's clock is (America/New_York), rather than
  # A Coruña, which is what ../../noctalia/default.nix still says — noctalia's
  # weather widget and nightlight schedule therefore disagree with this page
  # until that one is changed too.
  #
  # Fixed coordinates: auto-location is not wired up, so this goes wrong while
  # travelling (see the T16g migration).
  weather = {
    place = "New York";
    latitude = 40.7128;
    longitude = -74.006;
  };

  # PRs come from the personal account only. `gh auth token --user` picks this
  # one out of the two the keyring holds (the other is the work account).
  githubUser = "Danielhp95";

  # services.ollama in ../../non_home_manager_config/ollama.nix listens here.
  # Spelled out rather than read from osConfig: home.nix is also used by the
  # standalone home-manager entrypoint, which has no NixOS config to read.
  ollamaUrl = "http://127.0.0.1:11434";
}
