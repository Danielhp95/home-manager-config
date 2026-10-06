{
  lib,
  pkgs,
  config,
  ...
}:

# Vimium's settings as data. Nix can't apply them (Vimium reads storage.sync;
# HM's extensions.settings only writes storage.local), so they are rendered in
# the shape Vimium's exporter writes. Restore by hand on a new machine: Vimium
# Options -> Backup and Restore -> ~/.local/share/vimium/vimium-settings.json.
#
# The one palette-dependent key, the hint/vomnibar CSS, is also written into
# Firefox's storage.sync database on every switch (activation script below), so
# a palette change needs no import. It takes effect when Firefox next starts:
# Vimium reads its settings once at load.

let
  startPage = import ./firefox-start-page-wanderer/shared.nix;
  p = import ../../palette;

  vimiumSettings = {
    # Vimium stays off entirely here (empty passKeys): editors, canvases and
    # anything with its own vim bindings.
    exclusionRules =
      map
        (pattern: {
          inherit pattern;
          passKeys = "";
        })
        [
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

    # Hints and vomnibar in the selected palette (./vimium-hints.nix).
    userDefinedLinkHintCss = import ./vimium-hints.nix { inherit lib p; };
  };
in
{
  home.file.".local/share/vimium/vimium-settings.json".text = builtins.toJSON vimiumSettings;

  # Updates only userDefinedLinkHintCss inside Vimium's row, leaving every other
  # option as last saved in its UI. sync_change_counter is bumped only when the
  # value changes, so Firefox Sync uploads it and a no-op switch stays a no-op.
  # SQLite in WAL mode tolerates the running browser; a missing database or row
  # (new profile, Vimium never opened) is skipped, the file above covers that.
  home.activation.vimiumPalette = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      db="${config.home.homeDirectory}/.mozilla/firefox/${config.programs.firefox.profiles.default.path}/storage-sync-v2.sqlite"
      css=$(cat ${pkgs.writeText "vimium-hints.css" vimiumSettings.userDefinedLinkHintCss})
      # Never store an empty value over the real CSS.
      if [ -f "$db" ] && [ -n "$css" ]; then
        q=$(printf '\047')
        sql_css=''${css//"$q"/"$q$q"}
        run ${lib.getExe pkgs.sqlite} -cmd '.timeout 5000' "$db" "
          UPDATE storage_sync_data
          SET data = json_set(data, '\$.userDefinedLinkHintCss', '$sql_css'),
              sync_change_counter = sync_change_counter + 1
          WHERE ext_id = '{d7742d87-e61d-4b78-b8a1-b469842139fa}'
            AND json_extract(data, '\$.userDefinedLinkHintCss') IS NOT '$sql_css';
        " || echo "vimiumPalette: could not update $db (Firefox busy?); import vimium-settings.json by hand" >&2
      fi
    )
  '';
}
