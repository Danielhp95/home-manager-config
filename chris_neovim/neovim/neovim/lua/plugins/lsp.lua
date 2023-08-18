local NixPlugin = require('helper').NixPlugin

-- LSP Configuration & Plugins
local LspConfig = NixPlugin('neovim/nvim-lspconfig')

-- Useful status updates for LSP
local fidget = NixPlugin('j-hui/fidget.nvim')
fidget.opts = {}
fidget.tag = "legacy"

-- Additional lua configuration, makes nvim stuff amazing!
local neodev = NixPlugin('folke/neodev.nvim')
neodev.lazy = true
neodev.opts = {
  library = {
    enabled = true,
    runtime = true,
    types = true,
    plugins = true,
  },
  setup_jsonls = true,
  lspconfig = true,
}

local on_attach = function(client, bufnr)
  -- show signature as you type
  local lsp_signature = require('lsp_signature')
  lsp_signature.setup({
    bind = true,
    handler_opts = { border = "rounded" },
    hi_parameter = "Visual",
    hint_enable = false,
  })

end

-- nushell LSP
local nvim_nu = NixPlugin('LhKipp/nvim-nu')
nvim_nu.config = function()
  require'nu'.setup{
      use_lsp_features = true, -- requires https://github.com/jose-elias-alvarez/null-ls.nvim
      -- lsp_feature: all_cmd_names is the source for the cmd name completion.
      -- It can be
      --  * a string, which is interpreted as a shell command and the returned list is the source for completions (requires plenary.nvim)
      --  * a list, which is the direct source for completions (e.G. all_cmd_names = {"echo", "to csv", ...})
      --  * a function, returning a list of strings and the return value is used as the source for completions
      all_cmd_names = [[nu -c 'help commands | get name | str join "\n"']]
  }
end
nvim_nu.dependencies = {
  NixPlugin('jose-elias-alvarez/null-ls.nvim')
}


-- lsp config
local lspconfig = NixPlugin('neovim/lspconfig')
lspconfig.dependencies = {
  nvim_nu,
  NixPlugin('hrsh7th/nvim-cmp'),
  NixPlugin('ray-x/lsp_signature.nvim')
}

lspconfig.init = function ()
end


lspconfig.config = function ()
  local lspconfig = require('lspconfig')

  -- https://github.com/neovim/nvim-lspconfig/wiki/Autocompletion
  -- https://github.com/hrsh7th/cmp-nvim-lsp/issues/42#issuecomment-1283825572
  local capabilities = vim.tbl_deep_extend(
    'force',
    vim.lsp.protocol.make_client_capabilities(),
    require('cmp_nvim_lsp').default_capabilities(),
    -- File watching is disabled by default for neovim.
    -- See: https://github.com/neovim/neovim/pull/22405
    { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } }
  );

  -- local capabilities = vim.lsp.protocol.make_client_capabilities()
  -- capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

  -- bash
  lspconfig.bashls.setup({
    cmd = { "bash-language-server" },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- golang
  lspconfig.gopls.setup({
    cmd = { "gopls" },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- lua
  lspconfig.lua_ls.setup({
    cmd = { "lua-language-server"},
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          checkThirdParty = false,
          library = {
            vim.fn.expand "$VIMRUNTIME",
            --get_lvim_base_dir(),
            require("neodev.config").types(),
            "${3rd}/busted/library",
            "${3rd}/luassert/library",
          },
          maxPreload = 5000,
          preloadFileSize = 10000,
        },
        telemetry = { enable = false },
      }
    }
  })

  -- nix lsp
  lspconfig.nil_ls.setup({
    autostart = true;
    cmd = { "nil" },
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      ['nil'] = {
        formatting = {
          command = { "nixpkgs-fmt" }
        }
      }
    }
  })

  -- python lsp
  lspconfig.pyright.setup({
    cmd = { "pyright" },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- rust lsp
  lspconfig.rust_analyzer.setup({
    cmd = { "rust-analyzer" },
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- dockerfile lsp
  lspconfig.dockerls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- dockerfile lsp
  lspconfig.docker_compose_language_service.setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })

  -- yaml lsp
  lspconfig.yamlls.setup({
    on_attach = on_attach,
    settings = {
      redhat = {
        telemetry = {
          enabled = false,
        },
      },
    },
    capabilities = capabilities,
  })

  -- zk (zettelkasten note taking) lsp
  lspconfig.zk.setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })

end

LspConfig.dependencies = {
  NixPlugin("hrsh7th/cmp-nvim-lsp"),

  fidget,

  neodev,

  lspconfig,
}

return {
  LspConfig
}
