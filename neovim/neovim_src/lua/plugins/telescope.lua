local NixPlugin = require("helper").NixPlugin

local telescope = NixPlugin("nvim-telescope/telescope.nvim")
telescope.dependencies = {
	NixPlugin("nvim-lua/plenary.nvim"),
	"LinArcX/telescope-env.nvim",
	NixPlugin("debugloop/telescope-undo.nvim"),
	NixPlugin("nvim-telescope/telescope-cheat.nvim"),
	NixPlugin("nvim-telescope/telescope-live-grep-args.nvim"),
	NixPlugin("folke/trouble.nvim"),
	NixPlugin("nvim-telescope/telescope-fzf-native.nvim"),
	"nvim-telescope/telescope-dap.nvim",
}

telescope.config = function()
	local actions = require("telescope.actions")
	local action_set = require("telescope.actions.set")
	require("trouble").setup({ auto_preview = true })

	local function action_edit_ctrl_l(prompt_bufnr)
		return action_set.select(prompt_bufnr, "ctrl-l")
	end

	local function action_edit_ctrl_r(prompt_bufnr)
		return action_set.select(prompt_bufnr, "ctrl-r")
	end

	local action_layout = require("telescope.actions.layout")
	require("telescope").setup({
		defaults = {
			-- Appearance
			entry_prefix = "  ",
			prompt_prefix = "   ",
			selection_caret = ">  ",
			winblend = 0,
			border = {},
			borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
			set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
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
			layout_strategy = "horizontal",
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
					["<a-L>"] = function(prompt_bufnr)
						action_layout.cycle_layout_prev(prompt_bufnr)
					end,
					["<c-d>"] = actions.drop_all, -- Drop all selections from multi select
					["<c-l>"] = require("trouble.sources.telescope").open,
					["<c-f>"] = actions.send_to_qflist + actions.open_qflist,
					["<tab>"] = actions.toggle_selection,
					-- TODO: not working Select all
					["<c-a>"] = function(prompt_bufnr)
            local current_picker = require('telescope.state').get_current_picker(prompt_bufnr)
						local current_picker = require("telescope.state").get_current_picker(prompt_bufnr)
						local manager = current_picker.manager
						manager.selected = {}
						for i = 1, #manager.get_candidates() do
							table.insert(manager.selected, i)
						end
					end,
				},
				n = {
					["<esc>"] = actions.close,
					["<a-t>"] = require("trouble.sources.telescope"),
				},
			},
		},
		pickers = {
			buffers = {
				ignore_current_buffer = true,
				sort_mru = true,
				mappings = {
					i = { ["<c-r>"] = "delete_buffer" },
					n = { ["<c-r>"] = "delete_buffer" },
				},
			},
		},
		extensions = {
			fzf = {
				fuzzy = true, -- false will only do exact matching
				override_generic_sorter = true, -- override the generic sorter
				override_file_sorter = true, -- override the file sorter
				case_mode = "smart_case", -- or "ignore_case" or "respect_case"
				-- the default case_mode is "smart_case"
			},
		},
	})
	--
	--require('telescope').load_extension('gh')
	require("telescope").load_extension("live_grep_args")
	require("telescope").load_extension("undo")
	require("telescope").load_extension("env")
	-- require('telescope').load_extension('dap') -- TODO: fix
	require("telescope").load_extension("fzf")
end
return {
	telescope,
}
