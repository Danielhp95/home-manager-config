local NixPlugin = require("helper").NixPlugin

return {
	NixPlugin("is0n/fm-nvim", {
		opts = {
			mappings = {
				horz_split = "<C-x>",
				tabedit = "<C-t>",
				vert_split = "<C-v>",
			},
			float = { border = "double" },
		},
	}),
	{
		"stevearc/oil.nvim",
		opts = {},
		-- Optional dependencies
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
}
