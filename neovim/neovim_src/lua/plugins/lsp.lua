-- Here we do two things:
-- (1) Set up the configuration for packages used in the declaration of LSPs
-- (2) Call lspconfig.config function, which sets all the individual LSPs
local NixPlugin = require('helper').NixPlugin

-- Useful status updates for LSP
local fidget = NixPlugin('j-hui/fidget.nvim', { lazy = true, tag = 'legacy', opts = {} })

-- TODO: figure out what on attach does
local on_attach = function(client, bufnr)
  -- show signature as you type
  -- TODO: maybe there is cooler stuff that can be done here! Ask reddit

  -- TODO: I don't think I need this here
  require('lsp_signature').setup({
    bind = true, -- TODO: what is this?
    handler_opts = { border = "rounded" },
    hi_parameter = "Visual",
    hint_enable = false,
  })
end

-- LUA
-- Additional lua configuration, makes nvim stuff amazing!
local neodev = NixPlugin('folke/neodev.nvim', {
  lazy = true,
  opts =
  {
    library = {
      enabled = true,
      runtime = true,
      types = true,
      plugins = true,
    },
    setup_jsonls = true,
    lspconfig = true,
  }
})

-- LSP Configuration & Plugins
local lspconfig_toplevel = NixPlugin('neovim/nvim-lspconfig')
lspconfig_toplevel.dependencies = {
  fidget,
  NixPlugin('ray-x/lsp_signature.nvim'),
  NixPlugin('folke/neodev.nvim')
}
lspconfig_toplevel.config = function()
  local lspconfig = require('lspconfig')


  -- TODO: what even is this :P
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

  -- PYTHON
  lspconfig.pyright.setup({
    cmd = { "pyright-langserver", "--stdio" },
    on_attach = on_attach,
    capabilities = capabilities,
    -- TODO: add ruff as a formatting command like in nil_ls (nix)
  })
  -- lua
  lspconfig.lua_ls.setup({
    cmd = { "lua-language-server" },
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
  -- NIX
  lspconfig.nil_ls.setup({
    autostart = true,
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
  -- BASH
  lspconfig.bashls.setup({
    cmd = { "bash-language-server", "start" },
    on_attach = on_attach,
    capabilities = capabilities,
  })
  -- DOCKER
  lspconfig.docker_compose_language_service.setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })
  -- YAML
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
end

local LspSaga = NixPlugin("kkharji/lspsaga")
LspSaga.config = function() require('lspsaga').setup({}) end

return {
  lspconfig_toplevel,
  LspSaga
}
