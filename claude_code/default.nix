{
  config,
  pkgs,
  lib,
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

    # Personal, cross-project skills. Project-scoped skills stay in their
    # repo's .claude/skills (e.g. ~/Projects/sai). neovim-news-update is
    # deliberately absent: it writes state.json/reports/ into its own skill
    # directory, which a read-only store symlink would break.
    skills = {
      brainstorming = ./skills/brainstorming;
      domain-modeling = ./skills/domain-modeling;
      grilling = ./skills/grilling;
      grill-with-docs = ./skills/grill-with-docs;
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
