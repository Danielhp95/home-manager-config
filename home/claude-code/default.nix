{
  config,
  pkgs,
  lib,
  inputs,
  theme,
  ...
}:
let
  pal = theme;
  inherit (theme) colour;
  # "e08060" -> "224;128;96", the form the script's truecolor escapes take.
  rgb = colour.rgbSemicolons;

  # `--stdin`, or piped input never reaches $in in a nu script. The script's
  # at-sign placeholders are palette colours; replaceVars fails the build on a
  # missing or leftover one.
  statuslineScript = pkgs.replaceVars ./statusline-command.nu (
    lib.genAttrs [
      "accent"
      "accentDim"
      "ash"
      "bg"
      "error"
      "fgDim"
      "fgSoft"
      "gold"
      "mauve"
      "sage"
      "steel"
      "surface"
    ] (name: rgb pal.${name})
    # extra.heat: the effort pill's three steps past accent.
    // lib.listToAttrs (
      lib.zipListsWith (level: hex: lib.nameValuePair "heat${level}" (rgb hex)) [
        "High"
        "Xhigh"
        "Max"
      ] pal.extra.heat
    )
  );
  claude-statusline = pkgs.writeShellScriptBin "claude-statusline" ''
    exec ${lib.getExe pkgs.nushell} --stdin ${statuslineScript}
  '';

  # The live repo file, not a store copy, so it can't drift from the one
  # danvim's lsp.lua reads (the same path is written there).
  flakeDir = "${config.home.homeDirectory}/nix_config";
  noctaliaLuauDefs = "${flakeDir}/home/noctalia/noctalia.d.luau";

  # Skill directories from the flake inputs; the module symlinks each whole.
  superpower = name: "${inputs.superpowers}/skills/${name}";
  pocock = category: name: "${inputs.mattpocock-skills}/skills/${category}/${name}";
  socratic = name: "${inputs.socratic-skills}/skills/${name}";

  # One language server: its command, its arguments (the key is left out when
  # there are none) and the file extensions it takes, by language id.
  lsp =
    command: args: extensionToLanguage:
    {
      inherit command extensionToLanguage;
    }
    // lib.optionalAttrs (args != [ ]) { inherit args; };

  # Upstream ships `skill.md`; Claude Code only discovers `SKILL.md`.
  walkthrough-skill = pkgs.runCommandLocal "claude-code-skill-walkthrough" { } ''
    mkdir -p "$out"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/skill.md "$out/SKILL.md"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/references "$out/references"
  '';
in
{
  # statusLine and attribution are managed settings (../../nixos/claude-code.nix).
  # Claude Code rewrites the rest of ~/.claude/settings.json at runtime, so it
  # is seeded once, never a store symlink. The seed omits autoMode (work
  # details; this repo is public).
  home.activation.seedClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target=${config.home.homeDirectory}/.claude/settings.json
    if [ ! -e "$target" ]; then
      run mkdir -p "$(dirname "$target")"
      run install -m 644 ${./settings.json} "$target"
    fi
  '';

  programs.claude-code = {
    enable = true;

    # ~/.claude/CLAUDE.md, the instructions every session starts with.
    context = builtins.readFile ./context.md;

    # Personal, cross-project skills.
    skills = {
      # A file (not a directory) links only SKILL.md, so the skill directory
      # stays writable for the per-repo state, notes and reports the skill
      # writes there (the shipped profiles are linked below).
      repo-news = ./skills/repo-news/SKILL.md;

      # Interactive code-understanding skills (with quiz-me and guide-me below).
      walkthrough = "${walkthrough-skill}";
      codebase-to-course = "${inputs.codebase-to-course}";
    }
    # obra/superpowers: brainstorm -> plan -> execute, plus its disciplines.
    // lib.genAttrs [
      "brainstorming"
      "writing-plans"
      "executing-plans"
      "subagent-driven-development"
      "test-driven-development"
      "systematic-debugging"
      "verification-before-completion"
      "requesting-code-review"
      "receiving-code-review"
      "using-git-worktrees"
      "finishing-a-development-branch"
      "dispatching-parallel-agents"
      "using-superpowers"
    ] superpower
    # mattpocock/skills: grill-with-docs runs /grilling with /domain-modeling.
    // lib.genAttrs [ "grill-with-docs" "domain-modeling" ] (pocock "engineering")
    // lib.genAttrs [ "grilling" "grill-me" "teach" ] (pocock "productivity")
    // lib.genAttrs [ "quiz-me" "guide-me" ] socratic;

    # Mirrors danvim/lua/danvim/plugins/lsp.lua, minus leanls (runs from the
    # per-project elan toolchain, no stable nix binary to pin).
    lspServers = {
      python = lsp (lib.getExe pkgs.ty) [ "server" ] { ".py" = "python"; };
      lua = lsp (lib.getExe pkgs.lua-language-server) [ ] { ".lua" = "lua"; };
      # Same definitions file danvim feeds luau-lsp: noctalia injects its
      # plugin API as globals, so without it every symbol is unknown.
      luau = lsp (lib.getExe pkgs.luau-lsp) [ "lsp" "--definitions=${noctaliaLuauDefs}" ] {
        ".luau" = "luau";
      };
      nix = lsp (lib.getExe pkgs.nixd) [ ] { ".nix" = "nix"; };
      bash = lsp (lib.getExe pkgs.bash-language-server) [ "start" ] {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
      };
      yaml = lsp (lib.getExe pkgs.yaml-language-server) [ "--stdio" ] {
        ".yaml" = "yaml";
        ".yml" = "yaml";
      };
      json = lsp (lib.getExe' pkgs.vscode-langservers-extracted "vscode-json-language-server") [
        "--stdio"
      ] { ".json" = "json"; };
      docker = lsp (lib.getExe pkgs.docker-language-server) [ "start" "--stdio" ] {
        ".dockerfile" = "dockerfile";
      };
      latex = lsp (lib.getExe pkgs.texlab) [ ] { ".tex" = "latex"; };
      nushell = lsp (lib.getExe pkgs.nushell) [ "--lsp" ] { ".nu" = "nushell"; };
    };
  };

  home.packages = [ claude-statusline ];

  # repo-news's shipped profiles, one per directory under skills/repo-news/repos.
  # Linked a file at a time so each repos/<slug>/ stays writable; profiles the
  # skill creates at runtime are plain files beside them.
  home.file = lib.mapAttrs' (
    slug: _:
    lib.nameValuePair ".claude/skills/repo-news/repos/${slug}/profile.md" {
      source = ./skills/repo-news/repos/${slug}/profile.md;
    }
  ) (builtins.readDir ./skills/repo-news/repos);
}
