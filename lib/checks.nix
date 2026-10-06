# Checks of the theme as a whole, for `nix flake check`:
#   references    static files only use variables and slots that exist
#   fonts         every family ../fonts.nix names is provided by a font package
#   theme-<slug>  the whole system evaluates under each palette not selected
{
  pkgs,
  lib,
  theme,
  # self.nixosConfigurations.<host>
  host,
}:
let
  hm = lib.head (lib.attrValues host.config.home-manager.users);

  # Every match's first group, in order.
  matches = re: text: map lib.head (lib.filter lib.isList (builtins.split re text));
  withoutLuaComments =
    text:
    lib.concatStringsSep "\n" (
      lib.filter (line: builtins.match "[[:space:]]*--.*" line == null) (lib.splitString "\n" text)
    );

  # What a static file uses against what is generated for it. A name that is
  # not generated renders as the program's default (tmux, CSS) or reads as nil
  # (Lua), without a word.
  startPage = pkgs.callPackage ../home/firefox/firefox-start-page-wanderer/package.nix {
    inherit theme;
  };
  userChrome = lib.concatMapStrings (p: p.userChrome) (lib.attrValues hm.programs.firefox.profiles);
  lua = withoutLuaComments (builtins.readFile ../home/hyprland/hyprland.lua);
  luaVars = hm.wayland.windowManager.hyprland.settings;
  references = [
    {
      file = "home/tmux/tmux.conf";
      used = matches "#[{]@(color_[a-z0-9_]+)[}]" hm.programs.tmux.extraConfig;
      defined = matches "set -g @(color_[a-z0-9_]+) " hm.programs.tmux.extraConfig;
    }
    {
      file = "home/firefox/userChrome.css";
      used = matches "var[(]--(ember-[a-z0-9-]+)" userChrome;
      defined = matches "--(ember-[a-z0-9-]+):" userChrome;
    }
    {
      file = "the start page's style.css and app.js";
      used = lib.concatMap (f: matches "var[(]--(ember-[a-z0-9-]+)" (builtins.readFile f)) [
        ../home/firefox/firefox-start-page-wanderer/page/style.css
        ../home/firefox/firefox-start-page-wanderer/page/app.js
        ../home/firefox/firefox-start-page-wanderer/page/index.html
      ];
      defined = matches "--(ember-[a-z0-9-]+):" startPage.paletteCss.text;
    }
    {
      file = "home/hyprland/hyprland.lua (palette.<slot>)";
      used = matches "palette[.]([A-Za-z_]+)" lua;
      defined = lib.attrNames luaVars.palette._var;
    }
    {
      file = "home/hyprland/hyprland.lua (fonts.<role>)";
      used = matches "fonts[.]([A-Za-z_]+)" lua;
      defined = lib.attrNames luaVars.fonts._var;
    }
  ];
  unknown = lib.concatMap (
    r:
    map (name: "  ${r.file}: ${name} is used but not generated") (
      lib.unique (lib.filter (name: !(lib.elem name r.defined)) r.used)
    )
  ) references;

  # The family names, without the non-names beside them.
  families = lib.flatten (
    lib.attrValues (lib.filterAttrs (_: v: lib.isString v || lib.isList v) theme.fonts)
  );

  paletteLib = import ../palette/lib.nix;
  under =
    slug:
    host.extendModules {
      specialArgs.theme = import ../theme.nix {
        inherit lib;
        palette = paletteLib.select slug;
      };
    };
in
{
  references =
    assert lib.assertMsg (unknown == [ ]) "theme references:\n${lib.concatStringsSep "\n" unknown}";
    pkgs.writeText "theme-references" (
      lib.concatMapStrings (
        r: "${r.file}: ${toString (lib.length (lib.unique r.used))} names, all generated\n"
      ) references
    );

  # fontconfig substitutes without a word for a family nobody provides.
  fonts =
    pkgs.runCommand "font-families"
      {
        nativeBuildInputs = [ pkgs.fontconfig ];
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = host.config.fonts.packages; };
        families = lib.concatStringsSep "\n" families + "\n";
        passAsFile = [ "families" ];
      }
      ''
        export XDG_CACHE_HOME=$TMPDIR
        fc-list : family | tr ',' '\n' | sort -u > provided
        missing=0
        while IFS= read -r family; do
          grep -qxF -- "$family" provided || { echo "no font package provides: $family"; missing=1; }
        done < "$familiesPath"
        [ "$missing" = 0 ]
        cp "$familiesPath" $out
      '';
}
# Evaluation only: the system is never built, its drvPath is just forced
# (about 35 s per palette).
// lib.listToAttrs (
  map (slug: {
    name = "theme-${slug}";
    value = pkgs.writeText "theme-${slug}" (
      builtins.unsafeDiscardStringContext (under slug).config.system.build.toplevel.drvPath
    );
  }) (lib.filter (slug: slug != theme.meta.slug) paletteLib.slugs)
)
