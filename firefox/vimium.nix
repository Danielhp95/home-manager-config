{ ... }:

# Vimium's settings as data. Nix can't apply them (Vimium reads storage.sync;
# HM's extensions.settings only writes storage.local), so they are rendered in
# the shape Vimium's exporter writes. Restore by hand: Vimium Options -> Backup
# and Restore -> ~/.local/share/vimium/vimium-settings.json.

let
  startPage = import ./firefox-start-page-wanderer/shared.nix;

  vimiumSettings = {
    # Vimium stays off entirely here (empty passKeys): editors, canvases and
    # anything with its own vim bindings.
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

    # `o`/`O`/`b`/`B` aliases, shared with the start page's search box.
    searchEngines = builtins.concatStringsSep "\n" startPage.searchAliases;

    keyMappings = "# Insert your preferred key mappings here.\n";

    # `.` (default search): the start page's fallback, as in Firefox.
    searchUrl = startPage.defaultSearchUrl;

    # `/` searches by JavaScript regex rather than literal text.
    regexFindMode = true;

    # Take focus back from pages that grab it on load, so `j`/`k` work at once.
    grabBackFocus = true;

    # Pre-2.0 string encodings: Vimium 2.4 reads "true" as truthy and no
    # longer uses the other two keys.
    helpDialog_showAdvancedCommands = "true";
    optionsPage_showAdvancedOptions = "true";
    passNextKeyKeys = "[]";

    # Below 2.4 on purpose: restoring runs Vimium's 2.4 migration, which is what
    # points `t` at Firefox's new tab (the start page) instead of Vimium's own.
    settingsVersion = "2.3";

    # Hints and vomnibar in the "Hacker" theme orange, deliberately not Ember's.
    userDefinedLinkHintCss = builtins.readFile ./vimium-hints.css;
  };
in
{
  home.file.".local/share/vimium/vimium-settings.json".text =
    builtins.toJSON vimiumSettings;
}
