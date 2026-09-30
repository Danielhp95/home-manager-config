{ pkgs, ... }:
let
  # gh's markdown style (GLAMOUR_STYLE): glamour's dark.json in Ember, token
  # roles as in ../ipython/ipython_config.py. Text uses ANSI slots; chroma's
  # fixed 256-colour table maps only the xterm values of slots 1-7 back exactly
  # (bright ones and slot 8 tie), so code comments use grey 242, nearest muted.
  slot = {
    accent = "#800000";
    olive = "#008000";
    gold = "#808000";
    steel = "#000080";
    mauve = "#800080";
    sage = "#008080";
    fg = "#c0c0c0";
    comment = "#6c6c6c";
  };
  bold = color: {
    inherit color;
    bold = true;
  };
  glamourEmber = pkgs.writeText "glamour-ember.json" (builtins.toJSON {
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
    heading = bold "1" // {
      block_suffix = "\n";
    };
    h1 = {
      prefix = " ";
      suffix = " ";
      color = "0";
      background_color = "1";
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
      background_color = "#${(import ../palette.nix).surface}";
    };
    code_block = {
      color = "7";
      margin = 2;
      chroma = {
        text.color = slot.fg;
        error = bold slot.accent;
        comment = {
          color = slot.comment;
          italic = true;
        };
        comment_preproc.color = slot.gold;
        keyword = bold slot.mauve;
        keyword_reserved = bold slot.mauve;
        keyword_namespace = bold slot.mauve;
        keyword_type.color = slot.gold;
        name_builtin.color = slot.steel;
        name_tag.color = slot.mauve;
        name_class = bold slot.accent;
        name_constant.color = slot.sage;
        name_decorator.color = slot.gold;
        name_exception = bold slot.accent;
        name_function.color = slot.accent;
        literal_number.color = slot.sage;
        literal_string.color = slot.olive;
        literal_string_escape.color = slot.sage;
        generic_deleted.color = slot.accent;
        generic_emph.italic = true;
        generic_inserted.color = slot.olive;
        generic_strong.bold = true;
        generic_subheading.color = slot.comment;
      };
    };
    definition_description.block_prefix = "\n🠶 ";
  });
in
{
  home.sessionVariables.GLAMOUR_STYLE = "${glamourEmber}";

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
