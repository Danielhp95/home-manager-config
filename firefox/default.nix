{
  inputs,
  lib,
  pkgs,
  ...
}:

# Firefox draws its own chrome, so GTK theming never reaches it: userChrome.css
# paints it in the Ember palette. Nix owns the add-on set and the prefs below;
# Firefox Sync owns bookmarks, history, passwords and tabs.
#
# Add-on *settings* are out of nix's reach: Vimium and friends keep them in
# storage.sync, and Home Manager's extensions.settings only writes
# storage.local. Sync carries them; ./vimium.nix keeps Vimium's as a file.
#
# Not declared, having no firefox-addons package: GoLinks, History Export and
# reMarkable. Their .xpi files stay in the profile; a new machine would need
# programs.firefox.policies.ExtensionSettings with an AMO install_url.

let
  p = (import ../palette.nix).hash;

  # Shared with the start page's service and ./vimium.nix.
  startPage = import ./firefox-start-page-wanderer/shared.nix;

  # The existing profile; `path` and customKeys.json below must agree.
  profilePath = "1t50d90o.default";

  # What `:call firenvim#install(0)` writes imperatively, built here and run on
  # danvim's nvim (which ships the firenvim plugin).
  firenvimHost =
    let
      nvim = "${pkgs.danvim}/bin/nvim";

      # Verbatim from firenvim's s:get_executable_content(): take stdin before
      # the config loads, and keep print() off the protocol's stdout.
      earlyStdio = lib.concatStringsSep "|" [
        "let g:firenvim_config={'globalSettings':{},'localSettings':{'.*':{}}}"
        "let g:firenvim_i=[]"
        "let g:firenvim_o=[]"
        "let g:Firenvim_oi={i,d,e->add(g:firenvim_i,d)}"
        "let g:Firenvim_oo={t->[chansend(2,t)]+add(g:firenvim_o,t)}"
        "let g:firenvim_c=stdioopen({'on_stdin':{i,d,e->g:Firenvim_oi(i,d,e)},'on_print':{t->g:Firenvim_oo(t)}})"
      ];

      # Also verbatim: a failure reaches the browser as a message.
      run = lib.concatStringsSep "|" [
        "try"
        "call firenvim#run()"
        "catch /Unknown function/"
        ''call chansend(g:firenvim_c,["f\n\n\n"..json_encode({"messages":["Your plugin manager did not load the Firenvim plugin for Neovim."],"version":"0.0.0"})])''
        ''call chansend(2,["Firenvim not in runtime path. &rtp="..&rtp])''
        "qall!"
        "catch"
        ''call chansend(g:firenvim_c,["l\n\n\n"..json_encode({"messages": ["Something went wrong when running firenvim. See troubleshooting guide."],"version":"0.0.0"})])''
        "call chansend(2,[v:exception])"
        "qall!"
        "endtry"
      ];

      launcher = pkgs.writeShellScript "firenvim" ''
        dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}/firenvim"
        mkdir -p "$dir"
        chmod 700 "$dir"
        cd "$dir"
        unset NVIM_LISTEN_ADDRESS
        if [ -n "$VIM" ] && [ ! -d "$VIM" ]; then
          unset VIM
        fi
        if [ -n "$VIMRUNTIME" ] && [ ! -d "$VIMRUNTIME" ]; then
          unset VIMRUNTIME
        fi
        exec ${nvim} --headless \
          --cmd ${lib.escapeShellArg earlyStdio} \
          --cmd 'let g:started_by_firenvim = v:true' \
          -c ${lib.escapeShellArg run}
      '';
    in
    pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/firenvim.json" (
      builtins.toJSON {
        name = "firenvim";
        description = "Turn your browser into a Neovim GUI.";
        path = "${launcher}";
        type = "stdio";
        allowed_extensions = [ "firenvim@lacamb.re" ];
      }
    );
in
{
  imports = [
    ./vimium.nix
    # The start page and the user service behind it; see its default.nix.
    ./firefox-start-page-wanderer
  ];

  programs.firefox = {
    enable = true;

    # Not HM's XDG default: the existing profile lives here and HM won't move
    # it. Setting it also silences HM's warning (stateVersion < 26.05).
    configPath = ".mozilla/firefox";

    # Linked into ~/.mozilla/native-messaging-hosts; see firenvimHost above.
    nativeMessagingHosts = [ firenvimHost ];

    profiles.default = {
      id = 0;
      # Must match the existing directory, or Firefox starts an empty profile.
      path = profilePath;
      isDefault = true;

      # Store XPIs can't self-update; `nix flake update firefox-addons` does.
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
        # Ctrl+T opens the start page: Firefox has no new-tab URL pref, and
        # Vimium cannot run on about:newtab.
        new-tab-override
      ];

      # New Tab Override keeps these in storage.local, which HM can write (keys
      # from its v19 source). focus_website leaves focus in the page, so j/k/f
      # work at once. Firefox imports them only on the add-on's first run:
      # later edits need its data reset, or its own options page.
      extensions.settings."newtaboverride@agenedia.com" = {
        force = true;
        settings = {
          type = "custom_url";
          url = startPage.url;
          focus_website = true;
        };
      };

      # force: Firefox replaces the search.json.mozlz4 symlink on launch, so
      # engines added from a site vanish on restart; list them in `engines`.
      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
      };

      settings = {
        # Required for userChrome.css to be read at all.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Dark chrome, content following the OS. Measured, not from docs: only
        # content-override moves content (1 light, 0 dark, 2 OS); content-theme
        # does nothing and is pinned only so prefs.js can't keep a stale value.
        # Sites darkened anyway are Dark Reader's doing (its synced settings).
        "browser.theme.toolbar-theme" = 0;
        "browser.theme.content-theme" = 2;
        "layout.css.prefers-color-scheme.content-override" = 2;

        # The canvas of unstyled pages: content, not chrome, so not the palette.
        # Pinned to Firefox's default because a pref dropped from user.js keeps
        # its last value in prefs.js.
        "browser.display.background_color" = "#FFFFFF";

        # Rounded bottom window corners, to match WhiteSur's window shape.
        "widget.gtk.rounded-bottom-corners.enabled" = true;

        # --- add-on management -------------------------------------------
        # Nix owns the add-on set; Sync would reinstall removed add-ons.
        "services.sync.engine.addons" = false;
        # Keep syncing add-on *settings*, which the line above would stop too.
        "services.sync.engine.extension-storage.force" = true;
        # Enable HM-installed add-ons without an approval prompt.
        "extensions.autoDisableScopes" = 0;

        # --- media -------------------------------------------------------
        # Widevine (DRM); Firefox downloads the CDM itself.
        "media.eme.enabled" = true;
        # VA-API decode on the iGPU; the session sets LIBVA_DRIVER_NAME=iHD.
        "media.ffmpeg.vaapi.enabled" = true;

        # --- privacy -----------------------------------------------------
        "browser.contentblocking.category" = "standard";
        "privacy.clearHistory.formdata" = true;
        "privacy.clearOnShutdown_v2.formdata" = true;
        "browser.download.deletePrivate.chosen" = true;

        # No prefetch/speculative-connection prefs: uBlock Origin owns those.

        # --- start page ---------------------------------------------------
        # Startup and Home open the start page too (new tabs are the add-on's).
        "browser.startup.homepage" = startPage.url;
        # 1 = the homepage. Pinned: a pref absent from user.js keeps its
        # prefs.js value.
        "browser.startup.page" = 1;

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

      # The palette as custom properties, so userChrome.css stays plain CSS.
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
  # Ctrl+S opens Split View (no WebExtension API reaches it); key_savePage is
  # cleared because it also sits on Ctrl+S. Schema: CustomKeys.sys.mjs, where
  # Ctrl is "accel" and keys are upper-case. Firefox writes this file only when
  # about:keyboard edits a key, replacing the symlink: edit here instead.
  home.file.".mozilla/firefox/${profilePath}/customKeys.json".text =
    builtins.toJSON {
      key_addTabSplitView = {
        modifiers = "accel";
        key = "S";
      };
      key_savePage = { };
    };
}
