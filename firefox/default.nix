{ pkgs, ... }:

# Firefox's chrome is drawn by Firefox itself, not by GTK — the WhiteSur GTK
# theme only ever reached its native file dialogs. This module paints the
# browser UI in the same Ember / WhiteSur-Dark-orange palette as everything
# else (../palette.nix) via userChrome.css, and pins the add-on set and the
# hand-tuned about:config prefs so a fresh machine reconstitutes the browser.
#
# NOTE this takes over the existing on-disk profile rather than creating a new
# one: `path` is the pre-existing profile directory (~/.mozilla/firefox/
# 1t50d90o.default), so history, logins and extensions are untouched. Home
# Manager does rewrite ~/.mozilla/firefox/profiles.ini (the old one is kept as
# profiles.ini.backup by the backupFileExtension setting in flake.nix).
#
# The split of responsibilities is deliberate:
#   nix owns  — the add-on set, the prefs below, the default search engine
#   Sync owns — bookmarks, history, passwords, open tabs, forms
# Hence `services.sync.engine.addons = false`: leaving it on lets Sync
# reinstall an add-on that was removed from `extensions.packages`.
#
# Add-on *settings* are out of reach either way: Vimium and friends keep theirs
# in storage.sync (storage-sync-v2.sqlite), while Home Manager's
# extensions.settings only writes the storage.local backend. Firefox Sync
# carries them instead — see services.sync.engine.extension-storage.force below.
# ./vimium-settings.json is a plain snapshot of Vimium's config kept for
# disaster recovery; nothing applies it, restore it by hand through Vimium's
# Options page -> Backup and Restore -> Choose a backup file.
#
# Three installed add-ons are *not* declared here because they have no package
# in the firefox-addons set: GoLinks (teamgolinks@gmail.com), History Export
# ({ce0db577-…}) and Unofficial reMarkable (remarkable@schutter.xyz, disabled).
# Home Manager links the extensions directory per-file, so their imperatively
# installed .xpi files survive on this machine — they just won't come back on a
# new one. Add them via `programs.firefox.policies.ExtensionSettings` with an
# addons.mozilla.org install_url if that ever matters.

let
  p = (import ../palette.nix).hash;
in
{
  programs.firefox = {
    enable = true;

    # Home Manager's default moved to $XDG_CONFIG_HOME/mozilla/firefox and it
    # warns on every build while home.stateVersion < 26.05. Pinned to the legacy
    # path rather than migrated: the profile below is an existing on-disk one,
    # and the move is manual (Home Manager relocates neither the profile
    # directory nor the native messaging hosts firenvim relies on).
    configPath = ".mozilla/firefox";

    profiles.default = {
      id = 0;
      # Must match the existing directory name, otherwise Firefox starts on an
      # empty profile.
      path = "1t50d90o.default";
      isDefault = true;

      # Pinned to whatever the firefox-addons input locks; `nix flake update
      # firefox-addons` is how these move now, since store XPIs are read-only
      # and Firefox can no longer update them itself.
      extensions.packages = with pkgs.firefox-addons; [
        ublock-origin
        darkreader
        sponsorblock
        vimium
        firenvim
        violentmonkey
        tab-session-manager
        zhongwen
        export-cookies-txt
      ];

      # `force` is required because Firefox replaces the search.json.mozlz4
      # symlink on every launch. Consequence: OpenSearch engines added from a
      # website are wiped on restart — declare them in `engines` instead.
      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
      };

      settings = {
        # Required for userChrome.css to be read at all.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Dark chrome + dark built-in pages, regardless of what the desktop
        # portal reports.
        "browser.theme.toolbar-theme" = 0;
        "browser.theme.content-theme" = 0;
        "layout.css.prefers-color-scheme.content-override" = 0;

        # Paint the pre-render background in our bg instead of white, which
        # kills the white flash when a page is still loading.
        "browser.display.background_color" = p.bg;

        # Rounded bottom window corners, to match WhiteSur's window shape.
        "widget.gtk.rounded-bottom-corners.enabled" = true;

        # --- add-on management -------------------------------------------
        # Nix is the source of truth for the extension set; see the header.
        "services.sync.engine.addons" = false;
        # ...but NOT for extension *settings*, which nix cannot reach: add-ons
        # like Vimium keep their config in storage.sync (storage-sync-v2.sqlite),
        # while Home Manager's extensions.settings only writes the storage.local
        # backend. Firefox derives the extension-storage engine from
        # engine.addons unless this force pref exists (see
        # services-sync/engines/extension-storage.sys.mjs), so without it the
        # line above would also stop syncing Vimium/Dark Reader/SponsorBlock
        # settings between machines.
        "services.sync.engine.extension-storage.force" = true;
        # Accept profile-scope add-ons dropped in by Home Manager instead of
        # holding each one behind a manual approval prompt.
        "extensions.autoDisableScopes" = 0;

        # --- media -------------------------------------------------------
        # Widevine, for DRM'd video. Firefox still downloads the CDM blob into
        # the profile at runtime; only the switch is declarable.
        "media.eme.enabled" = true;

        # --- privacy -----------------------------------------------------
        "browser.contentblocking.category" = "standard";
        "privacy.clearHistory.formdata" = true;
        "privacy.clearOnShutdown_v2.formdata" = true;
        "browser.download.deletePrivate.chosen" = true;

        # network.prefetch-next, network.dns.disablePrefetch and
        # network.http.speculative-parallel-limit are deliberately absent:
        # uBlock Origin owns those via extension-settings.json, and declaring
        # them here would just fight the extension on every start.

        # --- UI ----------------------------------------------------------
        "sidebar.visibility" = "hide-sidebar";
        "sidebar.verticalTabs.dragToPinPromo.dismissed" = true;
        "browser.ml.linkPreview.collapsed" = true;
        "accessibility.typeaheadfind.flashBar" = 0;
        "browser.bookmarks.showMobileBookmarks" = false;

        # Trim the add-on manager down to extensions, themes and plugins.
        "extensions.ui.dictionary.hidden" = true;
        "extensions.ui.locale.hidden" = true;
        "extensions.ui.mlmodel.hidden" = true;
        "extensions.ui.sitepermission.hidden" = true;

        # --- forms & search ----------------------------------------------
        "dom.forms.autocomplete.formautofill" = true;
        "services.sync.engine.creditcards" = true;
        "browser.search.region" = "ES";
      };

      # The palette is injected as custom properties so userChrome.css stays a
      # plain stylesheet with no Nix interpolation inside it.
      userChrome = ''
        :root {
          --ember-bg: ${p.bg};
          --ember-bg-alt: ${p.bgAlt};
          --ember-bg-deep: ${p.bgDeep};
          --ember-surface: ${p.surface};
          --ember-border: ${p.border};
          --ember-fg: ${p.fg};
          --ember-fg-dim: ${p.fgDim};
          --ember-accent: ${p.accent};
          --ember-accent-bright: ${p.accentBright};
        }

      ''
      + builtins.readFile ./userChrome.css;
    };
  };
}
