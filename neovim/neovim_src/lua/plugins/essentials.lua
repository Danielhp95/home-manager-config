local NixPlugin = require("helper").NixPlugin

-- sets the cwd to the parent of the buffer that has a .git or Makefile
-- Didn't quite work for some reason. Try again in future
-- vim.api.nvim_create_autocmd("BufEnter", {
-- 	callback = function(ctx)
-- 		local root = vim.fs.root(ctx.buf, {".git", "Makefile"})
-- 		if root then vim.uv.chdir(root) end
-- 	end,
-- })

local should_profile = os.getenv("NVIM_PROFILE")
if should_profile then
	require("profile").instrument_autocmds()
	if should_profile:lower():match("^start") then
		require("profile").start("*")
	else
		require("profile").instrument("*")
	end
end

local function toggle_profile()
	local prof = require("profile")
	if prof.is_recording() then
		prof.stop()
		vim.ui.input({ prompt = "Save profile to:", completion = "file", default = "profile.json" }, function(filename)
			if filename then
				prof.export(filename)
				vim.notify(string.format("Wrote %s", filename))
			end
		end)
	else
		prof.start("*")
	end
end
vim.keymap.set("", "<f1>", toggle_profile)

return {
	NixPlugin("bmichaelb/sniprun", {
		build = "bash install.sh",
		config = function()
			require("sniprun").setup({
				live_mode_toggle = "enable",
				selected_interpreters = { "Python3_fifo" },
				repl_enable = { "Python3_fifo" },
				display = { "VirtualTextOk", "LongTempFloatingWindow", "TempFloatingWindow" },
				borders = "double",
				interpreter_options = {
					Python3_fifo = {
						venv = { "/home/dev/venv" }, -- Specifically for Sony AI
					},
				},
			})
		end,
	}),
	"sanfusu/neovim-undotree",
	NixPlugin("folke/which-key.nvim"),
	NixPlugin("windwp/nvim-autopairs", { event = "InsertEnter", opts = {} }),
	NixPlugin("nvim-tree/nvim-tree.lua", { opts = {} }),
	NixPlugin("kylechui/nvim-surround"),
	"stevearc/profile.nvim",
	{ "Danielhp95/tmpclone-nvim", opts = {} },
	{
		"nyngwang/NeoZoom.lua",
		opts = { winopts = { offset = "left", height = 0.99, width = 0.99 } },
	},
	{ "ellisonleao/glow.nvim", config = true, cmd = "Glow" }, -- Markdown preview
}
