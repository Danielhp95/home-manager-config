-- [[ Setting options ]]
-- See `:help vim.o`

vim.g.nofoldenable = true
vim.g.completeopt = "menu,menuone,noselect"
vim.g.noswapfile = true
vim.g.oscyank_max_length = 100000000
vim.g.timeoutlen = 100
vim.g.nowrap = true


vim.o.grepprg = "rg --vimgrep --no-heading --smart-case"
vim.o.grepformat = "%f:%l:%c:%m,%f:%l:%m"
vim.o.relativenumber = true
vim.o.autoread = true
vim.o.showcmd = true
vim.o.showmatch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.termguicolors = true
vim.o.inccommand = "split"
vim.o.incsearch = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.cursorline = true
vim.o.wrap = true
vim.o.autoindent = true
vim.o.copyindent = true
vim.o.splitbelow = false
vim.o.splitright = true
vim.o.number = true
  -- This breaks nvim by making the file title show up everytime there's an addition!!!
  -- title = true
vim.o.undofile = true
vim.o.hidden = true
vim.o.list = true
vim.o.background = "dark"
vim.o.backspace = "indent,eol,start"
vim.o.undolevels = 1000000
vim.o.undoreload = 1000000
vim.o.foldmethod = "indent"
vim.o.foldnestmax = 10
vim.o.foldlevel = 10
vim.o.scrolloff = 3
vim.o.sidescrolloff = 5
vim.o.listchars = "tab:  ,trail:●,nbsp:○"
vim.o.clipboard = "unnamed,unnamedplus"
vim.o.formatoptions = "tcqj"
vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"
vim.o.fileencodings = "utf-8"
vim.o.bomb = true
vim.o.binary = true
vim.o.matchpairs = "(:),{:},[:],<:>"
vim.o.expandtab = true
vim.o.wildmode = "list:longest,list:full"
