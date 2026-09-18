{ pkgs, ... }:
{
  home.packages = with pkgs; [
    libgit2
  ];
  # Structural diffs for `git diff`. git.enable is explicit: the module
  # stopped wiring diff.external automatically, and until this was set difft
  # was installed but git never called it.
  programs.difftastic = {
    enable = true;
    git.enable = true;
  };
  # Installs gh and declares the credential helper in the HM git config, so
  # it no longer depends on the ~/.gitconfig that `gh auth setup-git` wrote
  # (that file can be deleted; hosts.yml with the token stays gh's own).
  # settings mirrors what ~/.config/gh/config.yml already held.
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
        ds = "diff --staged";
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

        # Something like showing desdencindg lists of commit merges
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
