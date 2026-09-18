{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # The statusline reads Claude Code's JSON payload on stdin; `--stdin` is
  # required for piped input to reach $in when nu runs a script file.
  claude-statusline = pkgs.writeShellScriptBin "claude-statusline" ''
    exec ${lib.getExe pkgs.nushell} --stdin ${./statusline-command.nu}
  '';

  # Live repo path, not a store copy: danvim's lsp.lua reads the same file at
  # runtime, and pinning it here would let the two drift between rebuilds.
  noctaliaLuauDefs = "${config.home.homeDirectory}/nix_config/noctalia/noctalia.d.luau";

  # Skill sources are flake inputs (see flake.nix); each value is a store path
  # to the skill's directory, which the module symlinks whole.
  superpower = name: "${inputs.superpowers}/skills/${name}";
  pocock = category: name: "${inputs.mattpocock-skills}/skills/${category}/${name}";
  socratic = name: "${inputs.socratic-skills}/skills/${name}";

  # Upstream names its file `skill.md`; Claude Code only discovers `SKILL.md`,
  # so wrap it in a directory with the expected name.
  walkthrough-skill = pkgs.runCommandLocal "claude-code-skill-walkthrough" { } ''
    mkdir -p "$out"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/skill.md "$out/SKILL.md"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/references "$out/references"
  '';
in
{
  # settings.json is deliberately NOT managed here: Claude Code rewrites it at
  # runtime (model switches, /config, permission setup), and a store symlink
  # would either break those writes or be silently replaced by them. The
  # statusLine entry inside it just calls `claude-statusline`, which this
  # module keeps on PATH and up to date across generations.
  programs.claude-code = {
    enable = true;

    context = ''
      # Global instructions

      Never add Claude/AI attribution anywhere: no "Generated with Claude
      Code" footers, no "Co-Authored-By: Claude" trailers, no Claude-Session
      links — in commits, PRs, code comments, or documentation.
    '';

    # Personal, cross-project skills, sourced from upstream repos via flake
    # inputs. neovim-news-update is deliberately absent: it writes
    # state.json/reports/ into its own skill directory, which a read-only
    # store symlink would break.
    skills = {
      # obra/superpowers: brainstorm -> plan -> execute workflow and its
      # supporting disciplines.
      brainstorming = superpower "brainstorming";
      writing-plans = superpower "writing-plans";
      executing-plans = superpower "executing-plans";
      subagent-driven-development = superpower "subagent-driven-development";
      test-driven-development = superpower "test-driven-development";
      systematic-debugging = superpower "systematic-debugging";
      verification-before-completion = superpower "verification-before-completion";
      requesting-code-review = superpower "requesting-code-review";
      receiving-code-review = superpower "receiving-code-review";
      using-git-worktrees = superpower "using-git-worktrees";
      finishing-a-development-branch = superpower "finishing-a-development-branch";
      dispatching-parallel-agents = superpower "dispatching-parallel-agents";
      using-superpowers = superpower "using-superpowers";

      # mattpocock/skills: grill-with-docs runs /grilling with /domain-modeling.
      grill-with-docs = pocock "engineering" "grill-with-docs";
      domain-modeling = pocock "engineering" "domain-modeling";
      grilling = pocock "productivity" "grilling";
      grill-me = pocock "productivity" "grill-me";
      teach = pocock "productivity" "teach";

      # Interactive code-understanding skills.
      quiz-me = socratic "quiz-me";
      guide-me = socratic "guide-me";
      walkthrough = "${walkthrough-skill}";
      codebase-to-course = "${inputs.codebase-to-course}";
    };

    # Mirrors danvim/lua/danvim/plugins/lsp.lua, minus leanls (runs from the
    # per-project elan toolchain, no stable nix binary to pin).
    lspServers = {
      python = {
        command = "${pkgs.ty}/bin/ty";
        args = [ "server" ];
        extensionToLanguage = {
          ".py" = "python";
        };
      };
      lua = {
        command = "${pkgs.lua-language-server}/bin/lua-language-server";
        extensionToLanguage = {
          ".lua" = "lua";
        };
      };
      luau = {
        command = "${pkgs.luau-lsp}/bin/luau-lsp";
        # Same definitions file danvim feeds luau-lsp: noctalia injects its
        # plugin API as globals, so without it every symbol is unknown.
        args = [
          "lsp"
          "--definitions=${noctaliaLuauDefs}"
        ];
        extensionToLanguage = {
          ".luau" = "luau";
        };
      };
      nix = {
        command = "${pkgs.nixd}/bin/nixd";
        extensionToLanguage = {
          ".nix" = "nix";
        };
      };
      bash = {
        command = "${pkgs.bash-language-server}/bin/bash-language-server";
        args = [ "start" ];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
      yaml = {
        command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".yaml" = "yaml";
          ".yml" = "yaml";
        };
      };
      json = {
        command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".json" = "json";
        };
      };
      docker = {
        command = "${pkgs.docker-language-server}/bin/docker-language-server";
        args = [
          "start"
          "--stdio"
        ];
        extensionToLanguage = {
          ".dockerfile" = "dockerfile";
        };
      };
      latex = {
        command = "${pkgs.texlab}/bin/texlab";
        extensionToLanguage = {
          ".tex" = "latex";
        };
      };
      nushell = {
        command = "${pkgs.nushell}/bin/nu";
        args = [ "--lsp" ];
        extensionToLanguage = {
          ".nu" = "nushell";
        };
      };
    };
  };

  home.packages = [ claude-statusline ];
}
