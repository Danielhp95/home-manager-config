# The palette schema: what a palette file must supply, and the shape every
# consumer gets back through ../palette (default.nix).
#
# A palette file (./<slug>.nix) is a plain attrset of exactly:
#   dark, light   the 25 semantic slots (`slotNames`)
#   ansi          ANSI colour name -> colour reference, where it differs from
#                 `ansiDefaults` (red and brightRed always: they have none)
#   extra         colours outside the slots (`extraShape`); the ones in
#                 `extraDefaults` only where they are not that slot
#   roles         name -> name tables, one for both halves (`roleShape`)
#   meta          everything that is not a colour (`metaShape`)
# Colours are bare lowercase hex, no '#'. A colour reference is a slot name
# (that slot, in the half being built), a colour (the same in both halves) or
# a { dark, light } pair of either. A palette file states decisions; what
# every palette would write alike is a default here.
#
# A built palette is:
#   <slot>              the 25 dark slots, bare hex
#   slots               the same 25 as one attrset, for consumers that
#                       enumerate them (Hyprland's Lua table, CSS variables)
#   ansi                term in ANSI order, a list of 16
#   term, extra         attrsets (the dark half's)
#   hash                slots, ansi, term and extra again, with '#'
#   light               the light half: slots, ansi, term, hash, and the
#                       extras that are written per half
#   roles, meta         attrsets, as written in the palette file
#
# `meta` holds functions of pkgs (the GTK, cursor and icon packages), so a
# built palette cannot be serialised whole (`builtins.toJSON`, `nix eval
# --json`): select the colour attributes.
let
  inherit (builtins)
    attrNames
    concatLists
    concatMap
    concatStringsSep
    elem
    elemAt
    filter
    genList
    isAttrs
    isBool
    isFunction
    isInt
    isList
    isString
    length
    listToAttrs
    mapAttrs
    match
    removeAttrs
    typeOf
    ;

  # Every palette, by file name. Listed, not read from the directory: a flake
  # drops untracked files, and a listed file that is missing fails loudly.
  slugs = [
    "ember"
    "tokyo-night-violet"
  ];

  # ── Schema ───────────────────────────────────────────────────────────────
  slotNames = [
    "bgDeep"
    "bg"
    "bgAlt"
    "surface"
    "border"
    "divider"
    "fg"
    "fgSoft"
    "fgDim"
    "muted"
    "accent"
    "accentBright"
    "accentDim"
    "ash"
    "olive"
    "gold"
    "steel"
    "mauve"
    "sage"
    "error"
    "oliveBright"
    "goldBright"
    "steelBright"
    "mauveBright"
    "sageBright"
  ];

  # ANSI 0-15, in order.
  termNames = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
    "brightBlack"
    "brightRed"
    "brightGreen"
    "brightYellow"
    "brightBlue"
    "brightMagenta"
    "brightCyan"
    "brightWhite"
  ];

  # ANSI name -> colour reference, unless the palette's `ansi` says otherwise.
  # red and brightRed are missing on purpose: whether the terminal's red is
  # the accent or a true red is each palette's own call.
  ansiDefaults = {
    # The two that swap between halves.
    black = {
      dark = "bg";
      light = "fg";
    };
    white = {
      dark = "fg";
      light = "bg";
    };
    green = "olive";
    yellow = "gold";
    blue = "steel";
    magenta = "mauve";
    cyan = "sage";
    brightBlack = "muted";
    brightGreen = "oliveBright";
    brightYellow = "goldBright";
    brightBlue = "steelBright";
    brightMagenta = "mauveBright";
    brightCyan = "sageBright";
    brightWhite = "ffffff";
  };

  # 0 is one colour, n a list of exactly n, "halves" a { dark, light } pair.
  extraShape = {
    orange = "halves"; # vicinae's orange accent; nvim constants (tokyonight family)
    urgent = "halves"; # noctalia's error role: urgent workspaces, notification badges
    cyan = 0; # nvim types and specials (tokyonight family)
    fog = 0; # the start page's fog veil
    heat = 3; # the Claude statusline's high / xhigh / max effort pills
    artRamp = 5; # the start page's grade for the painting, darkest first
  };

  # The extras a palette may leave out, and the slot each then is. A new
  # colour that most palettes can take from a slot is added here and in
  # `extraShape` only.
  extraDefaults = {
    urgent = "error";
    orange = "steel";
    cyan = "sage";
  };

  # roles.<table>: every name in `names` must be there, and each value must be
  # one of `allowed`. Names, never colours: one table serves dark and light.
  roleShape = {
    # role -> ANSI name, for programs that can only name terminal slots
    # (IPython, prompt_toolkit, glamour). Not black/brightBlack: glamour's
    # chroma table (home/git/default.nix) has no stand-in for slots 0 and 8.
    ansi = {
      names = [
        "accent"
        "accentBright"
        "definition"
        "failure"
        "structure"
        "metadata"
        "emphasis"
        "value"
        "string"
      ];
      allowed = filter (n: n != "black" && n != "brightBlack") termNames;
    };
    # Material role -> slot (noctalia shell and greeter).
    material = {
      names = [
        "primary"
        "secondary"
        "tertiary"
        "hover"
      ];
      allowed = slotNames;
    };
    # hue name -> slot, for programs that ask for a colour by hue (vicinae).
    hues = {
      names = [
        "red"
        "yellow"
        "green"
        "cyan"
        "blue"
        "purple"
        "magenta"
      ];
      allowed = slotNames;
    };
    # tmux copy mode: the fill behind every search match, and behind the
    # current one. Colour is the only cue there, so the pair is per palette.
    search = {
      names = [
        "match"
        "current"
      ];
      allowed = slotNames;
    };
  };

  # The role tables a palette may leave out.
  roleDefaults.material = {
    primary = "accent";
    secondary = "gold";
    tertiary = "sage";
    hover = "accentBright";
  };

  # meta.slug is the file's name and meta.light.{name,slug} follow from
  # meta.name and it; a palette may still state them.
  #
  # A leaf is "string", "slug", "bool", "int", "function" (of pkgs), "slot"
  # (a slot name) or a list (one of these values); an attrset nests.
  metaShape = {
    name = "string";
    slug = "slug";
    description = "string";
    light = {
      name = "string";
      slug = "slug";
      description = "string";
    };
    gtk = {
      package = "function";
      # The theme directory under share/themes.
      name = "string";
      # Import the theme's gtk-4.0/gtk.css as user CSS (home-manager's
      # gtk.gtk4.theme). False for themes that must not be (adw-gtk3).
      gtk4Import = "bool";
      # Write ../home/hyprland/gtk-css.nix's named colours as user CSS. Only
      # themes that reference the names follow them (adw-gtk3, libadwaita itself).
      paletteCss = {
        gtk3 = "bool";
        gtk4 = "bool";
      };
    };
    # org.gnome.desktop.interface accent-color.
    adwaitaAccent = [
      "blue"
      "teal"
      "green"
      "yellow"
      "orange"
      "red"
      "pink"
      "purple"
      "slate"
    ];
    cursor = {
      package = "function";
      name = "string";
      size = "int";
    };
    icons = {
      package = "function";
      name = "string";
    };
    # The base colourscheme danvim loads (danvim's plugins/colorschemes.lua
    # has one lazy spec per family; an unknown one would load none).
    nvim.family = [
      "ember"
      "tokyonight"
    ];
    # kitty's cursor trail: the body and the thin band along its edge.
    trail = {
      fill = "slot";
      rim = "slot";
    };
  };

  halves = [
    "dark"
    "light"
  ];

  # ── Contract ─────────────────────────────────────────────────────────────
  # Each check returns a list of messages, so one failure reports every
  # problem in every palette at once.
  commas = concatStringsSep ", ";
  show =
    v:
    if isString v then
      ''"${v}"''
    else if isList v then
      "a list of ${toString (length v)}"
    else
      "a value of type ${typeOf v}";
  one = cond: msg: if cond then [ msg ] else [ ];

  # Exactly the names in `want`.
  checkKeys =
    at: want: v:
    if !isAttrs v then
      [ "${at}: expected an attribute set, got ${show v}" ]
    else
      let
        missing = filter (n: !(v ? ${n})) want;
        unknown = filter (n: !(elem n want)) (attrNames v);
      in
      one (missing != [ ]) "${at}: missing ${commas missing}"
      ++ one (unknown != [ ]) "${at}: unknown ${commas unknown} (not in the schema; misspelt?)";

  # `check name value` for each wanted name that is there; checkKeys reports
  # the ones that are not.
  eachPresent =
    want: v: check:
    if isAttrs v then concatMap (n: if v ? ${n} then check n v.${n} else [ ]) want else [ ];

  checkHex =
    at: v:
    one (
      !(isString v && match "[0-9a-f]{6}" v != null)
    ) "${at}: ${show v} is not six lowercase hex digits without '#'";

  checkHexSet =
    names: at: v:
    checkKeys at names v ++ eachPresent names v (n: checkHex "${at}.${n}");

  # The resolved ANSI colours. Their names are checked once, as `ansi` (what
  # the file wrote); a reference that is no slot name arrives here unresolved.
  checkTerm =
    _: v:
    checkKeys "ansi" termNames (v.dark or null)
    ++ concatMap (
      h:
      eachPresent termNames (v.${h} or null) (
        n: x:
        one (
          !(isString x && match "[0-9a-f]{6}" x != null)
        ) "ansi.${n} (${h}): ${show x} is neither a slot name nor six lowercase hex digits"
      )
    ) halves;

  checkExtra =
    at: v:
    checkKeys at (attrNames extraShape) v
    ++ eachPresent (attrNames extraShape) v (
      n: x:
      let
        size = extraShape.${n};
        here = "${at}.${n}";
      in
      if size == "halves" then
        checkHexSet halves here x
      else if size == 0 then
        checkHex here x
      else if !isList x || length x != size then
        [
          "${here}: expected a list of ${toString size} colours, got ${show x}"
        ]
      else
        concatLists (genList (i: checkHex "${here}[${toString i}]" (elemAt x i)) size)
    );

  checkRoles =
    at: v:
    checkKeys at (attrNames roleShape) v
    ++ eachPresent (attrNames roleShape) v (
      table: t:
      let
        shape = roleShape.${table};
        here = "${at}.${table}";
      in
      checkKeys here shape.names t
      ++ eachPresent shape.names t (
        n: x:
        one (
          !(isString x && elem x shape.allowed)
        ) "${here}.${n}: ${show x} is not one of ${commas shape.allowed}"
      )
    );

  checkMeta =
    shape: at: v:
    checkKeys at (attrNames shape) v
    ++ eachPresent (attrNames shape) v (
      n: x:
      let
        want = shape.${n};
        here = "${at}.${n}";
      in
      if isAttrs want then
        checkMeta want here x
      else if isList want then
        one (!(isString x && elem x want)) "${here}: ${show x} is not one of ${commas want}"
      else if want == "bool" then
        one (!isBool x) "${here}: expected true or false, got ${show x}"
      else if want == "int" then
        one (!isInt x) "${here}: expected an integer, got ${show x}"
      else if want == "function" then
        one (!isFunction x) "${here}: expected a function of pkgs, got ${show x}"
      else if want == "slot" then
        one (!(isString x && elem x slotNames)) "${here}: ${show x} is not a slot name"
      else if !isString x || x == "" then
        [ "${here}: expected a non-empty string, got ${show x}" ]
      else
        one (
          want == "slug" && match "[a-z0-9]+(-[a-z0-9]+)*" x == null
        ) "${here}: ${show x} is not a slug (lowercase letters and digits, single dashes)"
    );

  # A { dark, light } pair, both sides held to the same check.
  checkHalves =
    check: at: v:
    checkKeys at halves v ++ eachPresent halves v (h: check "${at}.${h}");

  topLevel = {
    dark = checkHexSet slotNames;
    light = checkHexSet slotNames;
    term = checkTerm;
    extra = checkExtra;
    roles = checkRoles;
    meta = checkMeta metaShape;
  };

  validate =
    slug: raw:
    checkKeys "top level" (attrNames topLevel) raw
    ++ eachPresent (attrNames topLevel) raw (n: topLevel.${n} n)
    ++ one (
      isAttrs raw
      && isAttrs (raw.meta or null)
      && isString (raw.meta.slug or null)
      && raw.meta.slug != slug
    ) "meta.slug: \"${raw.meta.slug}\" is not the file's name, \"${slug}\"";

  raw = listToAttrs (
    map (slug: {
      name = slug;
      value = import (./. + "/${slug}.nix");
    }) slugs
  );

  # ── Defaults ─────────────────────────────────────────────────────────────
  # A palette file as written -> the full palette the contract checks and the
  # views are built from: `ansi` resolved into `term`, the defaults filled in.
  # Nothing here may throw on a malformed file: the contract reports it.
  attrsOr = v: if isAttrs v then v else { };

  resolve =
    file: side: ref:
    if isAttrs ref then
      resolve file side (ref.${side} or null)
    else if isString ref && elem ref slotNames then
      (attrsOr (file.${side} or null)).${ref} or ref
    else
      ref;

  complete =
    slug: file:
    let
      meta = attrsOr (file.meta or null);
    in
    removeAttrs file [ "ansi" ]
    // {
      term = listToAttrs (
        map (side: {
          name = side;
          value = mapAttrs (_: resolve file side) (ansiDefaults // attrsOr (file.ansi or null));
        }) halves
      );
      extra = mapAttrs (
        n: v:
        let
          shape = extraShape.${n} or null;
        in
        if shape == "halves" then
          {
            dark = resolve file "dark" v;
            light = resolve file "light" v;
          }
        else if shape == 0 then
          resolve file "dark" v
        else
          v
      ) (extraDefaults // attrsOr (file.extra or null));
      roles = roleDefaults // attrsOr (file.roles or null);
      meta = {
        inherit slug;
      }
      // meta
      // {
        light = {
          name = "${if isString (meta.name or null) then meta.name else slug} Light";
          slug = "${slug}-light";
        }
        // attrsOr (meta.light or null);
      };
    };

  full = mapAttrs (slug: file: if isAttrs file then complete slug file else file) raw;

  problems = concatMap (
    slug:
    map (msg: "  palette/${slug}.nix: ${msg}") (
      one (
        isAttrs raw.${slug} && raw.${slug} ? term
      ) "term: lib.nix builds it; state ANSI colours in `ansi`"
      ++ validate slug full.${slug}
    )
  ) slugs;

  # ── Derived views ────────────────────────────────────────────────────────
  hashed =
    v:
    if isList v then
      map hashed v
    else if isAttrs v then
      mapAttrs (_: hashed) v
    else
      "#${v}";

  half =
    palette: side:
    let
      term = palette.term.${side};
      perHalf = filter (n: extraShape.${n} == "halves") (attrNames extraShape);
      views = {
        slots = palette.${side};
        ansi = map (n: term.${n}) termNames;
        inherit term;
        # Nothing reads the single-valued extras in light mode.
        extra =
          if side == "dark" then
            mapAttrs (n: v: if elem n perHalf then v.dark else v) palette.extra
          else
            listToAttrs (
              map (n: {
                name = n;
                value = palette.extra.${n}.light;
              }) perHalf
            );
      };
    in
    palette.${side} // views // { hash = hashed (palette.${side} // views); };

  build =
    palette:
    half palette "dark"
    // {
      light = half palette "light";
      # Never through `hashed`: names and functions, not colours.
      inherit (palette) roles meta;
    };

  all = mapAttrs (_: build) full;
in
# The gate sits at the root, so reading anything from any palette first checks
# every half of every palette: a light half nobody reads is still held to the
# schema. It runs once per evaluation (nix caches an imported file).
if problems != [ ] then
  throw "palette schema violated (schema: palette/lib.nix)\n${concatStringsSep "\n" problems}"
else
  {
    inherit
      all
      slugs
      slotNames
      termNames
      ;

    # The body of ./default.nix: one palette, with `all` beside it for
    # consumers that install every palette side by side.
    select =
      slug:
      if all ? ${slug} then
        all.${slug} // { inherit all; }
      else
        throw "palette: \"${slug}\" is not a palette; choose one of: ${commas slugs}";
  }
