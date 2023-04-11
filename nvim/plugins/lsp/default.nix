# LSP + Language specific configurations
{ pkgs, dsl, ... }:
with dsl; {
  plugins = with pkgs.vimPlugins; [
    nvim-lspconfig        # collection of LSP config files
    lspsaga-nvim          # extra UI for lsp

    lsp_signature-nvim    # To show method signatures
    fidget-nvim           # Gives info about nvim LSP status
    symbols-outline-nvim  # Side menu containing methods, fields, and general outline
    lsp-lense             # Adds codelense capabilities

    # Languages
    pkgs.nil    # Nix language server
    pkgs.texlab # latex
    pkgs.sumneko-lua-language-server # lua
    pkgs.nodePackages.pyright # Python
    pkgs.jsonnet-language-server # jsonnet
    neodev-nvim  # (TODO set it up)Lua vim functionality (because setting global vim doesn't work)
    null-ls-nvim # configurable LSP for unsupported languages
  ];

  use.neodev.setup = callWith { };  # TODO: get chris' config from Element

  use.lspsaga.setup = callWith { };
  use.lsp-lens.setup = callWith {
    include_declaration = true;
    sections = {
      definition = true;
      references = true;
      implementation = true;
    };
  };
  use.symbols-outline.setup = callWith { };

  lua = ''
    local ruff_path = '${pkgs.ruff}/bin/ruff'
    local black_path = '${pkgs.black}/bin/black'
    local stylua_path = '${pkgs.stylua}/bin/stylua'
  '' + builtins.readFile ./lsp.lua;

  use.lspconfig.pyright.setup = callWith {
    cmd = [ "${pkgs.nodePackages.pyright}/bin/pyright-langserver" "--stdio"];
  };


  use.lspconfig.jsonnet_ls.setup = callWith {
    cmd = [ "${pkgs.jsonnet-language-server}/bin/jsonnet-language-server" ];
  };

  # To have nice function signature show up in insert mode
  setup.lsp_signature = callWith { };
  setup.fidget = callWith { };

  # Lua: TODO: fix
  use.lspconfig.sumneko_lua.setup = callWith {
    cmd = [ "${pkgs.sumneko-lua-language-server}/bin/lua-language-server" ];
    settings = {
      Lua = {
        diagnostics = {
          # Get the language server to recognize the `vim` global
          globals = [ "vim" ];
        };
      };
    };
  };

  # Nix
  #use.lspconfig.rnix.setup = callWith {
  #  cmd = [ "${pkgs.rnix-lsp}/bin/rnix-lsp" ];
  #  capabilities = rawLua "require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())";
  #};

  use.lspconfig.nil_ls.setup = callWith {
    cmd = [ "${pkgs.nil}/bin/nil" ];
  #  capabilities = rawLua "require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())";
  };

  # Latex
  use.lspconfig.texlab.setup = callWith {
    cmd = [ "${pkgs.texlab}/bin/texlab" ];
  };
}
