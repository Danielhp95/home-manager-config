local NixPlugin = require('helper').NixPlugin

local whichKey = NixPlugin('folke/which-key.nvim')
whichKey.event = "VeryLazy"
whichKey.init = function()
  vim.o.timeout = true
  vim.o.timeoutlen = 300
end
whichKey.config = function()
  local wk = require('which-key')
  wk.setup({})
  wk.register({
    ["<leader>"] = {
      w = { name = "[w]indow Management Operations" },
      g = {
        name = "[g]it Operations",
        d = { name = "[d]iff Operations" },
        p = { name = "[p]ull/[p]ush Operations" },
      },
      f = { name = "[f] Telescope Operations" },
      a = { name = "[a] Leftover Operations" },
      r = { name = "[r]eload Operations" },
    },
  })
end

-- Adds git releated signs to the gutter, as well as utilities for managing changes
local gitsigns = NixPlugin('lewis6991/gitsigns.nvim')
gitsigns.opts = {
  -- See `:help gitsigns.txt`
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(bufnr)
    vim.keymap.set('n', '<leader>gp', require('gitsigns').prev_hunk, { buffer = bufnr, desc = '[G]o to [P]revious Hunk' })
    vim.keymap.set('n', '<leader>gn', require('gitsigns').next_hunk, { buffer = bufnr, desc = '[G]o to [N]ext Hunk' })
    vim.keymap.set('n', '<leader>ph', require('gitsigns').preview_hunk, { buffer = bufnr, desc = '[P]review [H]unk' })
  end,
}

-- Comment
-- "gc" to comment visual regions/lines
local comment = NixPlugin('numToStr/Comment.nvim')
comment.opts = {}

local autopairs = NixPlugin('windwp/nvim-autopairs')
autopairs.opts = {}

local surround = NixPlugin('kylechui/nvim-surround')
surround.version = "*" -- Use for stability; omit to use `main` branch for the latest features
surround.event = "VeryLazy"
surround.config = function()
  require("nvim-surround").setup({
    -- Configuration here, or leave empty to use defaults
  })
end

local bqf = NixPlugin('kevinhwang91/nvim-bqf')
bqf.opts = {
  filter = {
    fzf = {
      action_for = { ['ctrl-s'] = 'split', ['ctrl-t'] = 'tab drop' },
      extra_opts = { '--bind', 'ctrl-o:toggle-all', '--prompt', '> ' }
    }
  }
}


local togglelist = NixPlugin('milkypostman/vim-togglelist')
togglelist.init = function()
  vim.g.toggle_list_no_mappings = true
end

local colorizer = NixPlugin('nvchad/nvim-colorizer.lua/')
colorizer.opts = { }

return {
  -- Git related plugins
  NixPlugin('tpope/vim-fugitive'),

  -- Detect tabstop and shiftwidth automatically
  NixPlugin('tpope/vim-sleuth'),

  -- use `!!` to use sudo to write as root
  NixPlugin('lambdalisue/suda.vim'),

  NixPlugin('nvim-tree/nvim-web-devicons'),

  'mrjones2014/legendary.nvim',

  -- bqf usage of fzf fails when used as NixPlugin
  'junegunn/fzf',

  whichKey,
  gitsigns,
  comment,
  autopairs,
  surround,
  bqf,
  togglelist,
  colorizer,


  -- { -- Theme inspired by Atom
  --   'navarasu/onedark.nvim',
  --   priority = 1000,
  --   config = function()
  --     vim.cmd.colorscheme 'onedark'
  --   end,
  -- },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- dir = name_from_repo('nvim-lualine/lualine.nvim'),
    -- See `:help lualine.txt`
    opts = {
      options = {
        icons_enabled = false,
        theme = 'onedark',
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  -- {
  --   -- Add indentation guides even on blank lines
  --   'lukas-reineke/indent-blankline.nvim',
  --   -- Enable `lukas-reineke/indent-blankline.nvim`
  --   -- See `:help indent_blankline.txt`
  --   opts = {
  --     char = '┊',
  --     show_trailing_blankline_indent = false,
  --   },
  -- },
}
