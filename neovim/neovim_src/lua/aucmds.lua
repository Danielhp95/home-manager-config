-- [[ Highlight on yank ]]: Flashed text after being yanked
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- Starts hyprlang server 'hyprls'
-- vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
-- 	pattern = { "*.hl", "hypr*.conf" },
-- 	callback = function(event)
-- 		print(string.format("starting hyprls for %s", vim.inspect(event)))
-- 		vim.lsp.start({
-- 			name = "hyprlang",
-- 			cmd = { "hyprls" },
-- 			root_dir = vim.fn.getcwd(),
-- 		})
-- 	end,
-- })
