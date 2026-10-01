{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  pal = import ../palette.nix;
  colour = import ../lib/colour.nix { inherit lib; };
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
  # danvim's lsp.lua reads.
  noctaliaLuauDefs = "${config.home.homeDirectory}/nix_config/noctalia/noctalia.d.luau";

  # Skill directories from the flake inputs; the module symlinks each whole.
  superpower = name: "${inputs.superpowers}/skills/${name}";
  pocock = category: name: "${inputs.mattpocock-skills}/skills/${category}/${name}";
  socratic = name: "${inputs.socratic-skills}/skills/${name}";

  # Upstream ships `skill.md`; Claude Code only discovers `SKILL.md`.
  walkthrough-skill = pkgs.runCommandLocal "claude-code-skill-walkthrough" { } ''
    mkdir -p "$out"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/skill.md "$out/SKILL.md"
    ln -s ${inputs.walkthrough-skill}/skills/walkthrough/references "$out/references"
  '';
in
{
  # statusLine and attribution are managed settings (./managed-settings.nix).
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

    context = ''
      # Global instructions

      Never add Claude/AI attribution anywhere: no "Generated with Claude
      Code" footers, no "Co-Authored-By: Claude" trailers, no Claude-Session
      links — in commits, PRs, code comments, or documentation.

      # CLI tools not on PATH: omnibin-shell, never install

      omnibin can run almost any executable nixpkgs has shipped, in any
      version. The package is fetched from cache.nixos.org on first use, and
      nothing is installed.

      Use it when a command you need is not on PATH ("command not found",
      exit 127), or before you install a CLI or suggest that the user
      install one. Tools the project pins (devShell, package.json, …) still
      win: use theirs.

      ## 1. Check it exists (no download, instant)

        omnibin which <name>         newest version's store path; exit 1 if none
        omnibin which --all <name>   every version, one per line, tab-separated:
                                     jq@1.6<TAB>jq<TAB>0.0 MB<TAB>/nix/store/…/bin/jq
                                     (name@version, package attr, download size, path)

      - `which` takes bare names only: `omnibin which jq@1.6` always fails.
        To check a version: `omnibin which --all jq | grep '^jq@1\.6\s'`
      - `--all` is grouped by attr and sorted as text, not by version, so
        the last line is not the newest. To get one attr's versions, newest
        last: `omnibin which --all gcc | awk -F'\t' '$2 == "gcc"' | sort -V`
      - Exit 1 ("no package ever shipped …") means omnibin lacks it. Only
        then install or fall back, and tell the user.

      ## 2. Run it through the wrapper

      Your shell is not inside omnibin-shell. Names like `jq@1.6` are not on
      PATH, `/omnibin` does not exist, and the store paths `which` prints are
      not in the real /nix/store. Only commands run through the wrapper can
      see them. (If $OMNIBIN_TREE is set, you are already inside: run the
      names directly.)

        omnibin-shell jq@1.6 .foo data.json
        omnibin-shell bash -c 'jq@1.6 .foo a.json | sort > out.txt; rg@14.1.1 --version'

      The wrapper execs its arguments with no shell, so pipes, redirects,
      globs and `&&` go inside `bash -c '…'`. Exit code, cwd, env and stdin
      pass through.

      - Run only one omnibin-shell at a time. They share one mount point: a
        second one fails to mount ("fusermount3: failed to access mountpoint
        … Permission denied") and borrows the first one's mount. When the
        first exits, the second loses /nix/store, and even `ls` fails with
        127. So never run two from parallel tool calls, background jobs or
        subagents. Put several commands in one `bash -c` instead; that also
        saves ~1s of mount time per call.
      - Every call prints a 3-line "omnibin: …" banner on stdout, so pipes,
        redirects and $(…) belong inside `bash -c`:
          wrong: omnibin-shell jq . a.json > b.json    (banner ends up in b.json)
          right: omnibin-shell bash -c 'jq . a.json > b.json'
      - Inside, omnibin's names come after the host's on PATH: a bare `jq` is
        the host's jq if one is installed. Write `jq@<version>` to get
        omnibin's.
      - A first run downloads the package, roughly the size column (a
        python3 or gcc is 100+ MB). Raise the Bash timeout for big ones.

      ## Versions

      - If the task names a version, run exactly `<name>@<version>`. Never
        substitute a nearby version. For reproducibility, debugging,
        compatibility or historical builds, pick the version explicitly.
      - The version belongs to the package, not the executable: `bibtex@2023`
        is TeX Live 2023's bibtex. One name@version can match several attrs
        (`python3@3.11.9`: python3, python311Full, python3Minimal, …). When the
        attr matters, run that line's store path through omnibin-shell.

      ## Limits

      - Executables only. `python3@3.11.9` has just its stdlib; get
        libraries through the project's dependency mechanism (flake
        devShell, uv, venv).
      - Nix commands (nix build, nix-store, nh) do not work inside the
        wrapper. Run them outside it.
      - Names are searchable from March 2017 on, and very old binaries may
        not run on this kernel.
      - For questions `which` cannot answer, such as every executable a
        package ships, query the index:
          db=$(grep -o "/nix/store/[^']*\.db" "$(readlink -f "$(command -v omnibin)")")
          omnibin-shell sqlite3 "$db" "SELECT DISTINCT name FROM bins WHERE attr = 'imagemagick'"
        Tables: bins and latest (name, attr, version, digest); pkgs (attr,
        version, digest, last_seen); paths (digest, name, nar_url, nar_size).
    '';

    # Personal, cross-project skills.
    skills = {
      # A file (not a directory) links only SKILL.md, so the skill directory
      # stays writable for the state.json and reports/ the skill writes there.
      neovim-news-update = ./skills/neovim-news-update/SKILL.md;

      # obra/superpowers: brainstorm -> plan -> execute, plus its disciplines.
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
