local NixPlugin = require('helper').NixPlugin

-- cmp_luasnip will not start without nvim-cmp as a dependency when imported from nix

local CmpLuaSnip = NixPlugin('saadparwaiz1/cmp_luasnip', {
  dependencies = { NixPlugin('hrsh7th/nvim-cmp')
  }
})

-- nvim-cmp
local NvimCmp = NixPlugin('hrsh7th/nvim-cmp', {
  event = "InsertEnter",
  dependencies = {
    -- Snippet Engine & its associated nvim-cmp source
    NixPlugin('L3MON4D3/LuaSnip'),
    NixPlugin('rafamadriz/friendly-snippets'), -- Adds a number of user-friendly snippets
    -- Adds LSP completion capabilities
    NixPlugin('hrsh7th/cmp-nvim-lsp'),
    -- Remove?
    -- NixPlugin('hrsh7th/cmp-nixpkgs'),
    NixPlugin('hrsh7th/cmp-buffer'),
    NixPlugin('hrsh7th/cmp-path'),
    NixPlugin('GoldsteinE/compe-latex-symbols'),
    -- icons on cmp
    NixPlugin('onsails/lspkind.nvim'),
  }
})

NvimCmp.config = function()
  local cmp = require 'cmp'
  local luasnip = require 'luasnip'
  local lspkind = require 'lspkind'
  require('luasnip.loaders.from_vscode').lazy_load()
  luasnip.config.setup {
    -- https://stackoverflow.com/questions/70366949/how-to-change-tab-behaviour-in-neovim-as-specified-luasniplsp-popup
    region_check_events = "CursorHold,InsertLeave",
    -- those are for removing deleted snippets, also a common problem
    delete_check_events = "TextChanged,InsertEnter",
  }

  -- cmp setup
  cmp.setup {

    sources = {
      { name = 'path',    options = { trailing_slash = true } },
      { name = 'nvim_lsp' },
      { name = 'luasnip', max_item_count = 10 },
      { name = 'latex_symbols'},
      {
        name = 'buffer',
        options = { -- Show suggestions from all buffers
          get_bufnrs = function()
            return vim.api.nvim_list_bufs()
          end
        }
      },
    },

    snippet = { -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },

    mapping = cmp.mapping.preset.insert {
      ['<C-j>'] = cmp.mapping.select_next_item(),
      ['<C-k>'] = cmp.mapping.select_prev_item(),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-u>'] = cmp.mapping.scroll_docs(-4),
      ['<C-d>'] = cmp.mapping.scroll_docs(4),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Replace,
        select = true, -- TODO: figure out if we want this
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

    -- From https://github.com/onsails/lspkind.nvim/blob/master/README.md
    format = lspkind.cmp_format({
      mode = 'symbol',       -- show only symbol annotations
      maxwidth = 50,         -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
      ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
    }),

    -- Deals with how the cpm looks
    formatting = {
      format = function(entry, vim_item)
        local item = entry:get_completion_item()
        if not (vim_item.kind == "Attr") then
          vim_item.kind = require("lspkind").presets.default[vim_item.kind] .. " " .. vim_item.kind
        end
        -- Work inprogress: https://www.reddit.com/r/neovim/comments/unlj8d/is_there_any_way_to_show_types_in_nvimcmp/
        -- Unroll Auto-import so that it shows where the import would be coming from
        if entry.source.source.client and entry.source.source.client.name == "basedpyright" and item.detail == "Auto-import" and item.documentation then
          vim_item.menu = item.documentation.value:sub(#item.documentation.value:match("%S+") + 2) -- Remove first word
        -- if this is a constant, show the type. TODO: for some reason this is only showing up when selection is on this entry. Is this because of item.kind?
        elseif entry.source.source.client and entry.source.source.client.name == "basedpyright" and item.documentation then
          -- The documentation is "name: type", we want to remove "name: " from string
          local variable_type = item.documentation.value:gsub(string.format("```python\n%s: ", item.label), "")
          vim_item.menu = variable_type
        elseif item.detail then
          vim_item.menu = item.detail
        else
          vim_item.menu = ({
            path = "[Path]",
            buffer = "[Buffer]",
            nvim_lsp = "[LSP]",
            luasnip = "[LuaSnip]",
            nvim_lua = "[Lua]",
            latex_symbols = "[Latex]",
          })[entry.source.name]
        end
        return vim_item
      end,
    },

  }
end

return {
  CmpLuaSnip,
  NvimCmp
}
