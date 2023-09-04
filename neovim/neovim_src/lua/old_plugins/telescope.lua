local NixPlugin = require('helper').NixPlugin

local telescope = NixPlugin('nvim-telescope/telescope.nvim')
telescope.dependencies = {
  NixPlugin('nvim-lua/plenary.nvim'),
  NixPlugin('LinArcX/telescope-env.nvim'),
  NixPlugin('debugloop/telescope-undo.nvim'),
  NixPlugin('LinArcX/telescope-changes.nvim'),
  NixPlugin('LukasPietzschmann/telescope-tabs'),
  NixPlugin('MrcJkb/telescope-manix'),
  NixPlugin('nvim-telescope/telescope-cheat.nvim'),
  NixPlugin('nvim-telescope/telescope-file-browser.nvim'),
  NixPlugin('prochri/telescope-all-recent.nvim'),
}

telescope.config = function ()

  local actions = require 'telescope.actions'
  local builtin = require 'telescope.builtin'
  local action_set = require'telescope.actions.set'
  local function action_edit_ctrl_l(prompt_bufnr)
      return action_set.select(prompt_bufnr, "ctrl-l")
  end

  local function action_edit_ctrl_r(prompt_bufnr)
      return action_set.select(prompt_bufnr, "ctrl-r")
  end

  require('telescope').setup {
    defaults = {
      layout_config = {
        prompt_position = "bottom",
        vertical = {
          width = 0.97,
          height = 0.99,
          preview_cutoff = 10,
        },
        horizontal = {
          preview_cutoff = 10,
        },
      },
      sorting_strategy = "descending",
      layout_strategy = 'vertical',
      mappings = {
        i = {
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
          ["<CR>"] = actions.select_default + actions.center,
          ["<C-s>"] = actions.select_horizontal,
          ["<esc>"] = actions.close,
          ["<C-l>"] = action_edit_ctrl_l,
          ["<C-r>"] = action_edit_ctrl_r,
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,
          ["<C-o>"] = actions.results_scrolling_up,
          ["<C-e>"] = actions.results_scrolling_down,
          ["<C-z>"] = actions.complete_tag,
        },
        n = {
            ["<esc>"] = actions.close,
        },
      },
    },
  }
  local telescope_manix = require 'telescope-manix'
  require("telescope").load_extension "manix"
  require("telescope").load_extension "undo"
  require("telescope").load_extension "cheat"
  require('telescope').load_extension "env"
  require('telescope').load_extension "file_browser"

  -- Enable telescope fzf native, if installed
  pcall(require('telescope').load_extension, 'fzf')

  local map = vim.keymap.set

  -- See `:help telescope.builtin`
  map('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
  map('n', '<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
  map('n', '<leader>/', function()
    -- You can pass additional configuration to telescope to change theme, layout, etc.
    require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  map('n', '<leader>fa', builtin.git_commits, { desc = '[a]ll commits' })
  map('n', '<leader>fj', builtin.current_buffer_fuzzy_find, { desc = '[j] Fuzzy search in current buffer' })
  map('n', '<leader>fJ', function ()
    builtin.live_grep({ search_dirs = { "%:p" } })
  end, { desc = '[J] Fuzzy search in current directory' })
  map('n', '<leader>fc', builtin.git_branches, { desc = '[c] Git Branches' })
  map('n', '<leader>fC', builtin.git_bcommits, { desc = '[C]ommits since last fork' })
  map('n', '<leader>fs', builtin.git_status, { desc = 'Git [s]tatus' })
  map('n', '<leader>fg', builtin.live_grep, { desc = '[g] Fuzzy Search in Working Dir' })
  map('n', '<leader>fG', builtin.grep_string, { desc = '[G] Fuzzy Search your Cursor' })
  map('n', '<leader>fe', builtin.diagnostics, { desc = '[e]rrors / Diagnostics' })
  map('n', '<leader>fE', '<cmd>Telescope env<cr>', { desc = '[E]nvironment Variables' })
  map('n', '<leader>fd', builtin.lsp_document_symbols, { desc = '[d]ocument Symbols (LSP)' })
  map('n', '<leader>ff', builtin.find_files, { desc = 'Search [f]iles' })
  map('n', '<leader>fF', function ()
    builtin.live_grep({ default_text='function' })
  end, { desc = 'Grep for [F]unctions Only' })
  map('n', '<leader>fr', builtin.resume, { desc = '[r]esume Last Telescope Query' })
  -- vim.keymap.set('n', '<leader>fp', builtin.project, { desc = 'Search projects' })
  map('n', '<leader>ft', '<cmd>Telescope<cr>', { desc = '[t]elescope' })
  map('n', '<leader>fT', '<cmd>Telescope telescope-tabs list_tabs<cr>', { desc = '[T]elescope List Tabs' })
  map('n', '<leader>fh', builtin.command_history, { desc = 'Command [h]istory' })
  map('n', '<leader>fH', builtin.help_tags, { desc = '[H]elp tags' })
  map('n', '<leader>fm', builtin.keymaps, { desc = '[m]apped Key Bindings' })
  map('n', '<leader>fn', function ()
    telescope_manix.search{ cword = true }
  end , { desc = 'Ma[n]ix Search for selected word' })
  map('n', '<leader>fN', function ()
    telescope_manix.search{ cword = false }
  end, { desc = '[N] Manix Search (global)' })
  map('n', '<leader>fq', builtin.quickfix, { desc = '[q]uickfix list' })
  map('n', '<leader>f:', builtin.commands, { desc = '[:] Telescope Command Picker' })
  map('n', '<leader>f-', '<cmd>Telescope file_browser<cr>', { desc = '[-] Telescope File Browser' })
  map('n', '<leader>f;', builtin.command_history, { desc = '[;] Command History' })
  map('n', '<leader>f~', function ()
    builtin.find_files{search_dirs={'~'}}
  end, { desc = '[~] Search files in home directory' })
  map('n', '<leader>f.', function ()
    builtin.find_files{search_dirs={require('helper').GetCurrDir()}}
  end, { desc = '[.] Search files in current directory' })
  map('n', '<leader>fu', '<cmd>Telescope undo<cr>', { desc = '[u]ndo tree' })
  map('n', '<leader>fz', "<cmd>Telescope cheat fd<cr>", { desc = '[z] Cheatsheets' })
  map('n', '<leader>fw', builtin.grep_string, { desc = 'Current [W]ord search' })

  map('n', '<leader>gf', builtin.git_files, { desc = 'Search [G]it [F]iles' })
end

return {
  telescope,

  -- requires nix plugin, sqlite.lua must be installed via nix
  {
    'prochri/telescope-all-recent.nvim',
    dependencies = {
      NixPlugin('kkharji/sqlite.lua'),
    },
    opts = {
      database = {
        folder = vim.fn.stdpath("data"),
        file = "telescope-all-recent.sqlite3",
        max_timestamps = 10,
      },
      scoring = {
        recency_modifier = { -- also see telescope-frecency for these settings
          [1] = { age = 240, value = 100 }, -- past 4 hours
          [2] = { age = 1440, value = 80 }, -- past day
          [3] = { age = 4320, value = 60 }, -- past 3 days
          [4] = { age = 10080, value = 40 }, -- past week
          [5] = { age = 43200, value = 20 }, -- past month
          [6] = { age = 129600, value = 10 } -- past 90 days
        },
        -- how much the score of a recent item will be improved.
        boost_factor = 0.0001
      },
      default = {
        disable = true, -- disable any unkown pickers (recommended)
        use_cwd = true, -- differentiate scoring for each picker based on cwd
        sorting = 'recent' -- sorting: options: 'recent' and 'frecency'
      },
    },
  },


  -- Fuzzy Finder Algorithm which requires local dependencies to be built.
  -- Only load if `make` is available. Make sure you have the system
  -- requirements installed.
  NixPlugin('nvim-telescope/telescope-fzf-native.nvim'),
}
