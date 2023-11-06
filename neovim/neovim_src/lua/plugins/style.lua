local NixPlugin = require("helper").NixPlugin

local ColorSchemes = NixPlugin("navarasu/onedark.nvim", {
	dependencies = {
		NixPlugin("EdenEast/nightfox.nvim"),
		NixPlugin("nvim-tree/nvim-web-devicons"),
	},
	config = function()
		require("onedark").setup({ style = "deep", toggle_style_key = "<C-q>" })
		-- vim.api.nvim_command("colorscheme carbonfox")
	end,
})

local BufferLine = NixPlugin("akinsho/bufferline.nvim", {
	opts = {
		options = {
			-- Remove close icons as I never use them
			separator_style = "slope",
			buffer_close_icon = "",
			close_icon = "",
		},
	},
})

-- Status Bar
local LuaLine = NixPlugin("nvim-lualine/lualine.nvim", {
	opts = {
		options = {
			icons_enabled = true,
			theme = "auto",
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			globalstatus = false,
		},
		sections = {
			lualine_a = { "%{&spell ? 'SPELL' : ':3'}", "mode" },
			lualine_b = { "branch", "diff", "diagnostics" },
			lualine_c = { "filename" },
			lualine_x = { "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = { "filetype" },
			lualine_c = { "filename" },
			lualine_x = { "location" },
			lualine_y = {},
			lualine_z = {},
		},
		tabline = {},
		extensions = {},
	},
})

local IndentLines = NixPlugin("lukas-reineke/indent-blankline.nvim", {
	dependencies = {
		"TheGLander/indent-rainbowline.nvim", -- This plugin is used to make configuratino for indent-blankline.nvim
	},
	main = "ibl",
	opts = {
		indent = { char = "┊" },
	},
})

return {
	ColorSchemes,
	LuaLine,
	IndentLines,
	BufferLine,
}
