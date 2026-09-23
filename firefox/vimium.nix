{ ... }:

# Vimium's settings, as data.
#
# Nix cannot *apply* these. Vimium keeps its config in storage.sync
# (storage-sync-v2.sqlite) and Home Manager's programs.firefox
# extensions.settings only writes the storage.local backend, so there is no
# declarative path from here into the running add-on — see the header of
# ./default.nix. What this module does instead is own the *content*: the
# attrset below is the source of truth, and it is rendered to
#
#   ~/.local/share/vimium/vimium-settings.json
#
# in exactly the shape Vimium's own exporter produces. Restoring it is a manual
# step, and the only one:
#
#   Vimium Options -> Backup and Restore -> Choose a backup file
#   -> ~/.local/share/vimium/vimium-settings.json
#
# It is written outside the repo on purpose. Home Manager renders to read-only
# store symlinks, so pointing this at ./vimium-settings.json would drop a
# symlink into the git worktree.
#
# Keys and value *types* here are Vimium's, not ours — note that several
# booleans are stringly-typed ("true", "[]") because that is what Vimium
# round-trips. Do not "clean" them up; the restore reads them literally.

let
  vimiumSettings = {
    # Sites where Vimium keeps its hands off entirely (empty passKeys = the
    # whole keymap is suppressed, not just some keys). Editors, canvases and
    # anything with its own vim bindings.
    #
    # Deduped on the way in: miro.com and file:///* were each listed twice in
    # the exported snapshot, which Vimium tolerates but which says nothing.
    exclusionRules = map (pattern: { inherit pattern; passKeys = ""; }) [
      "https?://www.overleaf.com/project/*"
      "https?://tablesgenerator.com/*"
      "https?://localhost:8889/*"
      "https?://www.google.com/*"
      "https?://mangadex.org/*"
      "https?://docs.google.com/*"
      "https?://miro.com/*"
      "https?://playgameoflife.com/*"
      "https?://127.0.0.1:8888/*"
      "https?://q.uiver.app/*"
      "https?://app.diagrams.net/*"
      "https?://www.paypal.com/*"
      "https?://thisanimedoesnotexist.ai/*"
      "https?://gather.town/*"
      "https?://word-edit.officeapps.live.com/*"
      "https?://collabedit.com/*"
      "https?://codeshare.io/*"
      "file:///*"
    ];

    # `o`/`O`/`b`/`B` search aliases, now owned by
    # ./firefox-start-page-wanderer/shared.nix: the start page's search box
    # expands exactly the same aliases, and two hand-kept copies would drift
    # the first time one is edited. The commentary on the malformed `sg`/`sgn`
    # entries moved there with them.
    searchEngines = builtins.concatStringsSep "\n" (
      import ./firefox-start-page-wanderer/shared.nix
    ).searchAliases;

    # Custom key mappings. Empty: the snapshot's only entry was
    #   map c-k file:///home/sarios/Pictures/test.html
    # which points into /home/sarios — a home directory from a previous machine
    # that does not exist here, so the binding opened nothing. Dropped rather
    # than carried forward; add real mappings under the comment line.
    keyMappings = "# Insert your preferred key mappings here.\n";

    # `.` (default search) — matches the Firefox default in ./default.nix.
    searchUrl = "https://duckduckgo.com/?q=";

    # `/` searches by JavaScript regex rather than literal text.
    regexFindMode = true;

    # Steal focus back from pages that grab it on load, so `j`/`k` work
    # immediately instead of typing into a search box.
    grabBackFocus = true;

    # Stringly-typed on purpose — this is what Vimium writes.
    helpDialog_showAdvancedCommands = "true";
    optionsPage_showAdvancedOptions = "true";
    passNextKeyKeys = "[]";

    # Vimium's own schema version for the settings blob. Bump only when Vimium
    # does; a mismatch makes it run its migrations on restore.
    settingsVersion = "2.3";

    # Link hints and the vomnibar. Kept as a plain stylesheet in
    # ./vimium-hints.css for the same reason userChrome.css is one.
    #
    # NOTE this is NOT the Ember palette: it is the "Hacker theme" orange
    # (#E9873A) that Vimium has been carrying for years, and ../palette.nix
    # accent is #e08060. They are close enough to look intentional and far
    # enough apart to measure. Left alone here — retheming the hints is a
    # visible change, not a packaging one.
    userDefinedLinkHintCss = builtins.readFile ./vimium-hints.css;
  };
in
{
  home.file.".local/share/vimium/vimium-settings.json".text =
    builtins.toJSON vimiumSettings;
}
