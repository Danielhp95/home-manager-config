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
# ./vimium.nix therefore owns Vimium's config as *data* and renders it to
# ~/.local/share/vimium/vimium-settings.json; restoring it stays a manual step
# through Vimium's Options page -> Backup and Restore -> Choose a backup file.
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

  # The profile directory, spelled once — `path` below and the profile-scoped
  # files at the bottom of this module have to agree.
  profilePath = "1t50d90o.default";
in
{
  imports = [ ./vimium.nix ];

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
      path = profilePath;
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

        # Dark chrome, content that follows the OS light/dark setting — same
        # as a stock Firefox. content-override was pinned to 1 (force Light,
        # always) from 2026-08-20 to 2026-08-21 on the theory that "follow the
        # OS" was itself what recoloured pages. That traded one complaint for
        # a worse one: about:preferences/about:config/pdf.js/reader-mode stuck
        # light no matter the desktop theme, and any site the user actually
        # wanted dark got forced light too. Reverted to 2 on request.
        #
        # Measured on Firefox 154 in this exact GTK environment (dark:
        # gtk-application-prefer-dark-theme = 1, WhiteSur-Dark-orange; fresh
        # profiles under Xvfb, one pref changed at a time, screenshotted):
        #   content-override = 1  ->  content is Light, unconditionally.
        #   content-override = 0  ->  content is Dark, unconditionally.
        #   content-override = 2  ->  content follows the OS (dark, here).
        #   browser.theme.content-theme = 0 / 1 / 2  ->  no effect on content
        #                             whatsoever; Firefox also rewrites this
        #                             pref itself from the active theme. Kept
        #                             pinned only so a value dropped from
        #                             user.js can't linger in prefs.js
        #                             (prefs.js is never pruned), not because
        #                             it does anything.
        #   browser.theme.toolbar-theme = 0  ->  chrome only, confirmed: the
        #                             toolbars/tabs stay dark under every
        #                             combination above.
        # Do not re-derive these from Firefox source comments or web docs —
        # both disagree with the measurement. Re-measure instead.
        #
        # The recurring "Firefox is recolouring websites" complaint is NOT
        # this pref: it's Dark Reader (an installed add-on, see
        # extensions.packages below). Its synced settings
        # (storage-sync-v2.sqlite) read enabled=true, enabledByDefault=true,
        # with a long `disabledFor` exclusion list — i.e. it force-darkens
        # every site except the ones piled up in that list, backwards from
        # "opt in per site". Nix cannot fix this: that config lives in
        # Firefox Sync's extension-storage backend, which Home Manager's
        # extensions.settings does not write (see the file header — it only
        # reaches storage.local). Turn it off by hand: Dark Reader's toolbar
        # icon -> Settings (gear) -> Enabled by default -> off, leaving it as
        # a per-site opt-in for pages you actually want darkened.
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

  # --- keyboard shortcuts (about:keyboard) -------------------------------
  # Ctrl+S opens Split View instead of Save Page As.
  #
  # Split View is Firefox's own, native since 149 (this machine runs 155), and
  # no add-on can reach it: there is no WebExtension API for it, which is why
  # Vimium/Tridactyl/Surfingkeys all cannot bind it and why extensions that
  # advertise "split view" really juggle separate windows. The keyboard path is
  # about:keyboard (shipped 147), whose customisations live in this file —
  # verified against the shipped implementation, not docs:
  #
  #   browser/components/customkeys/CustomKeys.sys.mjs
  #     const config = new JSONFile({
  #       path: PathUtils.join(PathUtils.profileDir, "customKeys.json"),
  #     });
  #
  # Schema, from that file's own comment: a flat map of XUL <key> element id ->
  # { modifiers, key, keycode }, where `key` and `keycode` are mutually
  # exclusive and an empty object means "the default binding is cleared".
  # Modifiers are sorted and comma-joined; on Linux Ctrl serialises as "accel"
  # and printable keys are stored upper-case (CustomKeysParent.handleEvent
  # does `event.key.toUpperCase()`), so this is byte-for-byte what the
  # about:keyboard UI would have written.
  #
  # Safe to own from nix: CustomKeys only ever calls config.load() at window
  # open. It calls saveSoon() exclusively from changeKey/clearKey/resetKey/
  # resetAll — i.e. only when about:keyboard itself edits a shortcut. Nothing
  # rewrites this file behind us on startup, unlike search.json.mozlz4.
  #
  # The flip side is that about:keyboard becomes read-only for these two: it
  # writes atomically (temp file + rename), which would replace the Home
  # Manager symlink with a regular file and leave nix and the profile
  # disagreeing. Edit here and rebuild, not in the browser.
  #
  # key_savePage is cleared rather than left alone. Its default *is* Ctrl+S
  # (`<key id="key_savePage" data-l10n-id="save-page-shortcut"
  # command="Browser:SavePage" modifiers="accel"/>`), so leaving it bound would
  # put two <key> elements on the same chord and let document order decide.
  # Save Page As is still on File -> Save Page As, and can be given another
  # chord here if it turns out to be missed.
  #
  # Chrome-level keys are matched before content scripts see them, so this wins
  # over Vimium's keymap on every page — including the ones Vimium is excluded
  # from anyway (see ./vimium.nix).
  home.file.".mozilla/firefox/${profilePath}/customKeys.json".text =
    builtins.toJSON {
      key_addTabSplitView = {
        modifiers = "accel";
        key = "S";
      };
      key_savePage = { };
    };
}
