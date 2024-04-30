local NixPlugin = require("helper").NixPlugin

return {
	NixPlugin("tpope/vim-fugitive"),
	-- NixPlugin("lewis6991/gitsigns.nvim", { opts = {} }),
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"nvim-telescope/telescope.nvim", -- optional
			"sindrets/diffview.nvim", -- optional
			"ibhagwan/fzf-lua", -- optional
		},
		opts = {},
	},
	NixPlugin("sindrets/diffview.nvim", {
		opts = {
			view = {
				merge_tool = {
					layout = "diff3_mixed",
				},
			},
		},
	}),
	{
		"SuperBo/fugit2.nvim",
		opts = {},
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
			"nvim-lua/plenary.nvim",
			{
				"chrisgrieser/nvim-tinygit", -- optional: for Github PR view
				dependencies = { "stevearc/dressing.nvim" },
			},
		},
		cmd = { "Fugit2", "Fugit2Graph" },
		-- keys = {
		-- 	{ "<leader>F", mode = "n", "<cmd>Fugit2<cr>" },
		-- },
	},
}
