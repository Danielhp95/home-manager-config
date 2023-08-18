local NixPlugin = require('helper').NixPlugin

-- cmp_luasnip will not start without nvim-cmp as a dependency when imported from nix
local CmpLuaSnip = NixPlugin('saadparwaiz1/cmp_luasnip')
CmpLuaSnip.dependencies = {
  NixPlugin('hrsh7th/nvim-cmp')
}


-- nvim-cmp
local NvimCmp = NixPlugin('hrsh7th/nvim-cmp')
NvimCmp.event = "InsertEnter"
NvimCmp.dependencies = {
  -- Snippet Engine & its associated nvim-cmp source
  NixPlugin('L3MON4D3/LuaSnip'),

  -- Adds LSP completion capabilities
  NixPlugin('hrsh7th/cmp-nvim-lsp'),
  NixPlugin('hrsh7th/cmp-nixpkgs'),
  NixPlugin('hrsh7th/cmp-buffer'),
  NixPlugin('hrsh7th/cmp-path'),
  NixPlugin('hrsh7th/cmp-cmdline'),

  -- icons on cmp
  NixPlugin('onsails/lspkind.nvim'),

  -- speedup cmp
  -- NixPlugin('hrsh7th/cmp-rg'),

  -- Adds a number of user-friendly snippets
  NixPlugin('rafamadriz/friendly-snippets'),
}

-- [[ Configure nvim-cmp ]]
-- See `:help cmp`
NvimCmp.config = function ()
  local cmp = require 'cmp'
  local luasnip = require 'luasnip'
  local lspkind = require 'lspkind'
  require('luasnip.loaders.from_vscode').lazy_load()
  luasnip.config.setup {}

  -- cmp setup
  cmp.setup {

    sources = {
      { name = 'nixpkgs' },
      { name = 'nixos' },
      { name = 'nvim_lsp' },
      { name = "luasnip" },
      { name = 'vsnip' },
      --{ name = 'orgmode' },
      { name = 'path' },
      { name = 'buffer',  options = {
          get_bufnrs = function()
              return vim.api.nvim_list_bufs()
          end
      }},
      -- { name = "rg" },
    },

    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },

    mapping = cmp.mapping.preset.insert {
      ['<C-j>'] = cmp.mapping.select_next_item(),
      ['<C-k>'] = cmp.mapping.select_prev_item(),
      ['<C-Space>'] = cmp.mapping.complete(),
      --['<C-e>'] = cmp.mapping.close(),
      ['<C-u>'] = cmp.mapping.scroll_docs(-4),
      ['<C-d>'] = cmp.mapping.scroll_docs(4),
      ['<C-e>'] = cmp.mapping.abort(),
      -- ['<C-s>'] = cmp.mapping.confirm({ select = true }),
      -- ['<CR>'] = cmp.mapping.confirm({ select = false }),

      ['<CR>'] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Replace,
        select = true,
      },
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.locally_jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { 'i', 's' }),
    },

    format = lspkind.cmp_format({
      mode = 'symbol', -- show only symbol annotations
      maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
      ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
    }),

    formatting = {
        format = function(entry, vim_item)
            --vim_item.kind = require("lspkind").presets.default[vim_item.kind] .. " " .. vim_item.kind
            -- workaround for nix/nixpkgs
            if not (vim_item.kind == "Attr") then
              vim_item.kind = require("lspkind").presets.default[vim_item.kind] .. " " .. vim_item.kind
            end
            vim_item.menu = ({
                path = "[Path]",
                buffer = "[Buffer]",
                nvim_lsp = "[LSP]",
                luasnip = "[LuaSnip]",
                vsnip = "[VSnip]",
                nvim_lua = "[Lua]",
                latex_symbols = "[Latex]",
                --orgmode = "[Org]",
            })[entry.source.name]
            return vim_item
        end,
    },

  }

  -- cmp.setup.cmdline(':', {
  --   mapping = cmp.mapping.preset.cmdline({
  --     ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
  --     ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
  --   }),
  --   sources = cmp.config.sources({
  --     { name = 'path' }
  --   }, {
  --     { name = 'cmdline' }
  --   })
  -- })

end

return {
  CmpLuaSnip,
  NvimCmp
}
