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

        # Dark chrome only — websites are deliberately NOT forced to dark.
        # browser.theme.toolbar-theme governs the chrome/toolbar stylesheet
        # only (PreferenceSheet.cpp's aIsChrome branch), so forcing it to 0
        # can't leak into page content.
        #
        # content-theme and content-override are a different story: per
        # PreferenceSheet::Prefs::Load, content-override != {0,1} falls
        # through to ThemeDerivedColorSchemeForContent(), which then reads
        # content-theme — and *that* pref governs the color-scheme used for
        # actual web content (prefers-color-scheme results, plus default
        # scrollbar/form-widget rendering on unstyled pages), not just
        # about:* pages as the naming suggests. Setting content-theme = 0
        # here previously forced every site's content to dark unconditionally
        # (a real leak — this contradicted the comment that used to be here).
        # Both must be left at 2/non-0-1 so the fallback reaches
        # LookAndFeel::SystemColorScheme(), i.e. the real OS light/dark
        # preference. about:* pages still render dark in practice since the
        # desktop is dark, but real websites now track the OS setting instead
        # of being force-darkened. The white pre-render flash is killed in
        # userChrome.css by painting the tabpanel backdrop, which pages never
        # see.
        "browser.theme.toolbar-theme" = 0;
        "browser.theme.content-theme" = 2;
        "layout.css.prefers-color-scheme.content-override" = 2;

        # browser.display.background_color is the *document canvas* — the
        # colour an unstyled page paints itself with, page content and not
        # chrome. This module set it to the ember bg between cada87c and
        # 18debb1, which left every unstyled light-scheme page dark-on-black.
        # Dropping the line from nix did not undo that: Home Manager only
        # writes user.js, and a pref that disappears from user.js keeps its
        # last value in prefs.js forever. So it is pinned back to Firefox's
        # compiled-in default (#FFFFFF; the dark-scheme counterpart is the
        # separate browser.display.background_color.dark = #1C1B22, left
        # alone) to actively overwrite the stale profile value. Do not point
        # this at the palette again — chrome theming belongs in
        # userChrome.css.
        "browser.display.background_color" = "#FFFFFF";

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
        # Decode video through VA-API (iHD on the iGPU) instead of CPU.
        # The driver is installed system-wide (intel-media-driver) and the
        # session exports LIBVA_DRIVER_NAME=iHD; this pref is Firefox's gate.
        "media.ffmpeg.vaapi.enabled" = true;

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
