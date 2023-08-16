{ pkgs, ...}:
{
  home.packages = [pkgs.gh];
  programs.git = {
    enable = true;

    userName = "Daniel Hernandez";
    userEmail = "daniel.hernandez2@sony.com";

    difftastic.enable = true;

    extraConfig = {
      pull.rebase = false;
      pager = {
        diff = "difftastic";
        show = "difftastic";
        log = "difftastic";
        reflog = "difftastic";
      };
    };

    aliases = {
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

      # reset
      soft = "reset --soft";
      hard = "reset --hard";
      s1ft = "soft HEAD~1";
      h1rd = "hard HEAD~1";

      # logging
      lg =
        "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      plog =
        "log --graph --pretty='format:%C(red)%d%C(reset) %C(yellow)%h%C(reset) %ar %C(green)%aN%C(reset) %s'";

      # Short summary of changes from 1 day ago
      tlog =
        "log --stat --since='1 Day Ago' --graph --pretty=oneline --abbrev-commit --date=relative";

      # Something like showing desdencindg lists of commit merges
      rank = "shortlog --summary --numbered --no-merges";

      # delete merged branches
      bdm = "!git branch --merged | grep -v '*' | xargs -n 1 git branch -d";
    };
  };
}
