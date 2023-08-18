-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!

vim.o.autoread = true
vim.o.autoindent = true
vim.o.background = "dark"
vim.o.number = true
vim.o.relativenumber = true
vim.o.scrolloff = 3
vim.o.list = true
vim.o.listchars = "tab:→→,trail:●,nbsp:○"
vim.o.hidden = true
vim.o.ignorecase = true

-- tab width
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.expandtab = true
-- vim.o.noexpandtab = true
vim.o.smartindent = true

--extra
vim.o.grepformat = "%f:%l:%c:%m,%f:%l:%m"
vim.o.grepprg = "rg --vimgrep --no-heading --smart-case"
vim.o.undolevels = 1000000
vim.o.undoreload = 1000000
vim.o.wildmode = "list:longest,list:full"
vim.o.wrap = true
vim.o.sidescrolloff = 5
vim.o.smartcase = true
vim.o.splitbelow = false
vim.o.splitright = true

-- fold
vim.g.nofoldenable = true
vim.o.foldlevel = 1
vim.o.foldmethod = "indent"
vim.o.foldnestmax = 10

-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true
