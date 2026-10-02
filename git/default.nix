{
  pkgs,
  lib,
  config,
  ...
}:
let
  palette = import ../palette;

  # gh's markdown style (GLAMOUR_STYLE): glamour's dark.json through the
  # terminal's ANSI slots, token roles from palette.roles.ansi (shared with
  # ../ipython). Prose takes a slot number. Code goes through chroma's fixed
  # 256-colour table, which maps only the xterm values of slots 1-7 back
  # exactly (bright ones and slot 8 tie), so a role on a bright slot uses its
  # normal one, and comments take the table entry nearest `muted` that is no
  # darker than it.
  # ANSI slots 1-7: the number prose uses, and the xterm value chroma maps
  # back to it (a stand-in, not a colour: the terminal draws its own).
  number = {
    red = "1";
    green = "2";
    yellow = "3";
    blue = "4";
    magenta = "5";
    cyan = "6";
    white = "7";
  };
  xterm = {
    red = "#800000";
    green = "#008000";
    yellow = "#808000";
    blue = "#000080";
    magenta = "#800080";
    cyan = "#008080";
    white = "#c0c0c0";
  };
  # brightRed -> red: chroma cannot reach the bright slots.
  normal =
    name:
    let
      m = builtins.match "bright(.)(.*)" name;
    in
    if m == null then name else lib.toLower (builtins.elemAt m 0) + builtins.elemAt m 1;
  # role -> slot number (prose) / xterm stand-in (chroma).
  n = role: number.${normal palette.roles.ansi.${role}};
  x = builtins.mapAttrs (_: name: xterm.${normal name}) palette.roles.ansi;
  comment = "#${((import ../lib/xterm256.nix).nearestNoDarker palette.muted).hex}";

  bold = color: {
    inherit color;
    bold = true;
  };
  glamourStyle = pkgs.writeText "glamour-${palette.meta.slug}.json" (builtins.toJSON {
    document = {
      block_prefix = "\n";
      block_suffix = "\n";
      margin = 2;
    };
    block_quote = {
      indent = 1;
      indent_token = "│ ";
      color = "8";
    };
    list.level_indent = 2;
    heading = bold (n "accent") // {
      block_suffix = "\n";
    };
    h1 = {
      prefix = " ";
      suffix = " ";
      color = "0";
      background_color = n "accent";
      bold = true;
    };
    h2.prefix = "## ";
    h3.prefix = "### ";
    h4.prefix = "#### ";
    h5.prefix = "##### ";
    h6 = {
      prefix = "###### ";
      color = "8";
      bold = false;
    };
    strikethrough.crossed_out = true;
    emph.italic = true;
    strong.bold = true;
    hr = {
      color = "8";
      format = "\n--------\n";
    };
    item.block_prefix = "• ";
    enumeration.block_prefix = ". ";
    task = {
      ticked = "[✓] ";
      unticked = "[ ] ";
    };
    link = {
      color = "4";
      underline = true;
    };
    link_text = bold "3";
    image = {
      color = "5";
      underline = true;
    };
    image_text = {
      color = "8";
      format = "Image: {{.text}} →";
    };
    # Hex: surface has no ANSI slot.
    code = {
      prefix = " ";
      suffix = " ";
      color = "2";
      background_color = palette.hash.surface;
    };
    code_block = {
      color = "7";
      margin = 2;
      chroma = {
        text.color = xterm.white;
        error = bold x.failure;
        comment = {
          color = comment;
          italic = true;
        };
        comment_preproc.color = x.emphasis;
        keyword = bold x.structure;
        keyword_reserved = bold x.structure;
        keyword_namespace = bold x.structure;
        keyword_type.color = x.emphasis;
        name_builtin.color = x.metadata;
        name_tag.color = x.structure;
        name_class = bold x.definition;
        name_constant.color = x.value;
        name_decorator.color = x.emphasis;
        name_exception = bold x.failure;
        name_function.color = x.definition;
        literal_number.color = x.value;
        literal_string.color = x.string;
        literal_string_escape.color = x.value;
        generic_deleted.color = xterm.red;
        generic_emph.italic = true;
        generic_inserted.color = xterm.green;
        generic_strong.bold = true;
        generic_subheading.color = comment;
      };
    };
    definition_description.block_prefix = "\n🠶 ";
  });
in
{
  # A constant path, not the store path: a session variable keeps its value
  # until the next login, so a palette switch would leave gh on the old style.
  xdg.configFile."glamour/style.json".source = glamourStyle;
  home.sessionVariables.GLAMOUR_STYLE = "${config.xdg.configHome}/glamour/style.json";

  # Structural diffs for `git diff`; git.enable must be explicit, the module
  # no longer sets diff.external on its own.
  programs.difftastic = {
    enable = true;
    git.enable = true;
  };
  # gh plus its credential helper in the HM git config (no ~/.gitconfig from
  # `gh auth setup-git`; the token stays in gh's own hosts.yml).
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
  };
  programs.git = {
    enable = true;

    # ~/.config/git/ignore, git's default global excludes file
    ignores = [ "**/.claude/settings.local.json" ];

    settings = {
      user.name = "Daniel Hernandez";
      user.email = "daniel.hernandez2@sony.com";
      alias = {
        adog = "log --all --decorate --oneline --graph";
        a = "add -p";
        co = "checkout";
        cob = "checkout -b";
        f = "fetch -p";
        c = "commit";
        p = "push";
        ba = "branch -a";
        bd = "branch -d";
        bD = "branch -D";
        d = "diff";
        dc = "diff --cached";
        r = "restore";
        rs = "restore --staged";
        st = "status -sb";

        # Searching
        find-file = ''!f() { for branch in $(git for-each-ref --format="%(refname)" refs/heads); do if git ls-tree -r --name-only $branch | grep "$1" > /dev/null; then echo -e "\033[1;32m''${branch}\033[0m by \033[1;34m$(git log -1 --format="%cn" $branch)\033[0m"; git ls-tree -r --name-only $branch | nl -bn -w3 | grep "$1"; fi; done; :; }; f'';

        # reset
        soft = "reset --soft";
        hard = "reset --hard";
        s1ft = "soft HEAD~1";
        h1rd = "hard HEAD~1";

        # logging
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        plog = "log --graph --pretty='format:%C(red)%d%C(reset) %C(yellow)%h%C(reset) %ar %C(green)%aN%C(reset) %s'";

        # Short summary of changes from 1 day ago
        tlog = "log --stat --since='1 Day Ago' --graph --pretty=oneline --abbrev-commit --date=relative";

        # Commit counts per author
        rank = "shortlog --summary --numbered --no-merges";

        # delete merged branches
        bdm = "!git branch --merged | grep -v '*' | xargs -n 1 git branch -d";
      };
      pull.rebase = false;
      diff.mnemonicPrefix = true;
      diff.algorithm = "patience";
    };

  };
}
