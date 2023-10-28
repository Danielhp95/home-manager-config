local NixPlugin = require('helper').NixPlugin

local telescope = NixPlugin('nvim-telescope/telescope.nvim')
telescope.dependencies = {
  NixPlugin('nvim-lua/plenary.nvim'),
  "LinArcX/telescope-env.nvim",
  NixPlugin('debugloop/telescope-undo.nvim'),
  NixPlugin('LinArcX/telescope-changes.nvim'),
  NixPlugin('LukasPietzschmann/telescope-tabs'),
  NixPlugin('nvim-telescope/telescope-cheat.nvim'),
  'prochri/telescope-all-recent.nvim',
  NixPlugin('nvim-telescope/telescope-live-grep-args.nvim'),
  NixPlugin('folke/trouble.nvim'),
  NixPlugin('nvim-telescope/telescope-fzf-native.nvim'),
  "nvim-telescope/telescope-dap.nvim",
}

telescope.config = function()
  -- require'telescope-all-recent'.setup({})
  local actions = require('telescope.actions')
  local action_set = require('telescope.actions.set')
  require('trouble').setup({ auto_preview = true })

  local function action_edit_ctrl_l(prompt_bufnr)
    return action_set.select(prompt_bufnr, "ctrl-l")
  end

  local function action_edit_ctrl_r(prompt_bufnr)
    return action_set.select(prompt_bufnr, "ctrl-r")
  end

  local action_layout = require('telescope.actions.layout')
  require('telescope').setup {
    defaults = {
      -- Appearance
      entry_prefix = "  ",
      prompt_prefix = "   ",
      selection_caret = ">  ",
      color_devicons = true,
      path_display = { "absolute" },
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
      layout_strategy = 'horizontal',
      mappings = {
        i = {
          ["<C-u>"] = false,
          ["<C-q>"] = require("telescope-live-grep-args.actions").quote_prompt(),
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
          ["<CR>"] = actions.select_default + actions.center,
          ["<C-s>"] = actions.select_horizontal,
          -- ["<esc>"] = actions.close,
          ["<C-l>"] = action_edit_ctrl_l,
          ["<C-r>"] = action_edit_ctrl_r,
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,
          ['<s-j>'] = function(prompt_bufnr) action_layout.cycle_layout_next(prompt_bufnr) end,
          ['<s-k>'] = function(prompt_bufnr) action_layout.cycle_layout_prev(prompt_bufnr) end,
          ["<c-l>"] = require("trouble.providers.telescope").open_with_trouble,
          ["<c-f>"] = actions.send_to_qflist,
          ["<tab>"] = actions.toggle_selection,
        },
        n = {
          ["<esc>"] = actions.close,
          ["<a-t>"] = require("trouble.providers.telescope").open_with_trouble,
        },
      },
    },
    pickers = {
      buffers = {
        ignore_current_buffer = true,
        sort_mru = true,
        mappings = {
          i = { ['<c-r>'] = 'delete_buffer' },
          n = { ['<c-r>'] = 'delete_buffer' },
        },
      },
    },
    extensions = {
      fzf = {
        fuzzy = true,                   -- false will only do exact matching
        override_generic_sorter = true, -- override the generic sorter
        override_file_sorter = true,    -- override the file sorter
        case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
        -- the default case_mode is "smart_case"
      }
    }
  }
  --
  --require('telescope').load_extension('gh')
  require("telescope").load_extension("live_grep_args")
  require("telescope").load_extension("undo")
  require('telescope').load_extension("env")
  -- require('telescope').load_extension('dap') -- TODO: fix
  require('telescope').load_extension('fzf')


  function File_picker()
    vim.fn.system('git rev-parse --git-dir > /dev/null 2>&1')
    local is_git = vim.v.shell_error == 0
    if is_git then
      require 'telescope.builtin'.find_files()
    else
      vim.cmd 'Files'
    end
  end
end
return { telescope,

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
        recency_modifier = {                 -- also see telescope-frecency for these settings
          [1] = { age = 240, value = 100 },  -- past 4 hours
          [2] = { age = 1440, value = 80 },  -- past day
          [3] = { age = 4320, value = 60 },  -- past 3 days
          [4] = { age = 10080, value = 40 }, -- past week
          [5] = { age = 43200, value = 20 }, -- past month
          [6] = { age = 129600, value = 10 } -- past 90 days
        },
        -- how much the score of a recent item will be improved.
        boost_factor = 0.0001
      },
      default = {
        disable = true,    -- disable any unkown pickers (recommended)
        use_cwd = true,    -- differentiate scoring for each picker based on cwd
        sorting = 'recent' -- sorting: options: 'recent' and 'frecency'
      },
    },
  },

}
