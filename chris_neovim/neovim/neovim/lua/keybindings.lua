local map = vim.keymap.set

-- reload config
map('n', '<leader>rr', '<cmd>:source $MYVIMRC<cr>', { desc = '[r]eload neovim config' })

-- buffer mgmt
map('n', '<leader>wD', '<cmd>Bclose!<cr>', { desc = '[D]elete buffer aggressively' })
map('n', '<leader>wd', '<cmd>bd<cr>', { desc = '[d]elete buffer' })
map('n', '<leader>wj', '<cmd>bprev<cr>', { desc = '[j]: Previous buffer' })
map('n', '<leader>wk', '<cmd>bnext<cr>', { desc = '[k]: Next buffer' })
map('n', '<leader>wq', '<cmd>q<cr>', { desc = '[q]: Close buffer' })
map('n', '<leader>wt', '<cmd>tabedit<cr>', { desc = '[t]ab edit' })
map('n', '<leader>wv', '<cmd>vs<cr>', { desc = 'Split window [v]ertically' })
map('n', '<leader>ww', '<cmd>Telescope buffers<cr>', { desc = '[w]: Get buffer list' })
map('n', '<leader>wx', '<cmd>sp<cr>', { desc = '[x]: Split window horizontally' })

map('n', '<leader>re', '<cmd>e!<cr>', { desc = '[r][e]load (forced) current buffer' })

-- movement
map('n', 'H', '<cmd>tabp<cr>', { desc = "Go to previous tab" })
map('n', 'L', '<cmd>tabn<cr>', { desc = "Go to next tab" })
map('n', '<leader>h', '<cmd>wincmd h<cr>', { desc = 'Move cursor to buffer left' })
map('n', '<leader>j', '<cmd>wincmd j<cr>', { desc = 'Move cursor to buffer below' })
map('n', '<leader>k', '<cmd>wincmd k<cr>', { desc = 'Move cursor to buffer above' })
map('n', '<leader>l', '<cmd>wincmd l<cr>', { desc = 'Move cursor to buffer right' })

-- quickfix
map('n', '[q', '<cmd>cprev<cr>', { desc = 'Previous item in quickfix list' })
map('n', ']q', '<cmd>cnext<cr>', { desc = 'Next item in quickfix list' })
map('n', '<leader>qq', '<cmd>:call ToggleQuickfixList()<cr>', { desc = 'Open quickfix list' })
map('n', '<leader>ql', '<cmd>:call ToggleLocationList()<cr>', { desc = 'Open location list' })
map('n', '<leader>qw', '<cmd>:BqfToggle<cr>', { desc = 'Toggle quickfix extra info' })

-- yank
map('n', '<Leader>Y', 'v$:OSCYankVisual<CR>', {noremap = true})
map('n', '<Leader>yy', 'V:OSCYankVisual<CR>', {noremap = true})
map('v', '<Leader>y', ':OSCYankVisual<CR>', {noremap = true})

-- write current file with sudo
map('c', 'w!!', ':SudaWrite<CR>', { desc = "Escalate privileges with sudo and write current buffer" })

---- Git Shortcuts / Fugitive
-- Fugitive
function GitCurrentBranchName()
  local branch = vim.fn.system("git branch --show-current 2> /dev/null | tr -d 'n'")
  if branch ~= "" then
    return branch
  else
    return ""
  end
end
-- browse
map('n', '<leader>gg', '<cmd>Git<cr>', { desc = 'Open [g]it command' })
map('n', '<leader>gs', '<cmd>Git<cr>', { desc = 'Git [S]tatus' })
map('n', '<leader>gB', '<cmd>GBrowse<cr>', { desc = '[B]rowse file on GitHub' })
map('n', '<leader>gO', ':Git branch ', { desc = '[O]pen Branch command' })
map('n', '<leader>gR', ':Git rebase ', { desc = 'Open [R]ebase command' })
map('n', '<leader>gQ', '<cmd>Gclog<cr>', { desc = '[Q]: Open all commits log into quickfix list' })
map('n', '<leader>gb', '<cmd>Git blame<cr>', { desc = 'Git [b]lame' })
map('n', '<leader>gq', '<cmd>0Gclog<cr>', { desc = '[q]: Open current file commit log quickfix list' })
map('n', '<leader>gr', ':Git rebase --interactive<Space>', { desc = 'Interactive [r]ebase' })

-- commit/stage
map('n', '<leader>gC', '<cmd>Git commit -v -q --amend<cr>', { desc = '[C]ommit + amend' })
map('n', '<leader>gc', '<cmd>Git commit -v -q<cr>', { desc = '[c]ommit' })
map('n', '<leader>gw', '<cmd>Gwrite<cr>', { desc = '[w]rite + stage current file' })

-- diffs
map('n', '<leader>gdd', '<cmd>Gdiff<cr>', { desc = '[d]iff to staged' })
map('n', '<leader>gdg', ':Gdiff ', { desc = '[g]it diff (select your branch)' })
map('n', '<leader>gdh', '<cmd>Gdiff HEAD<cr>', { desc = '[h]: Diff to last commit on current file' })
map('n', '<leader>gdo', '<cmd>Gdiff origin/HEAD<cr>', { desc = 'Diff to [o]rigin HEAD' })

-- hunks
map('n', '<leader>ga', '<cmd>GitGutterStageHunk<cr>', { desc = '[a]: Gutter Stage Hunk' })
map('n', '<leader>gj', '<cmd>GitGutterNextHunk<cr>', { desc = '[j]: Go to next hunk' })
map('n', '<leader>gk', '<cmd>GitGutterPrevHunk<cr>', { desc = '[k]: Go to prev hunk' })
map('n', '<leader>gu', '<cmd>GitGutterUndoHunk<cr>', { desc = 'Gutter [u]ndo Hunk' })
map('n', '<leader>gm', ':Git merge ', { desc = 'Git [m]erge' })
map('n', '<leader>go', ':Git checkout ', { desc = '[o]pen Checkout command' })

-- push/pull
map('n', '<leader>gpO', ':Git push origin ', { desc = 'Push [O]rigin (complete)' })
map('n', '<leader>gpP', '<cmd>Git push<cr>', { desc = '[P]ush' })
map('n', '<leader>gpU', ':Git push upstream ', { desc = 'Push [U]pstream (complete)' })
map('n', '<leader>gpf', '<CMD>lua vim.cmd("Git push -u origin "..GitCurrentBranchName())<CR>', { desc = 'Push origin for [f]irst time, same name' })
map('n', '<leader>gpo', ':Git pull origin ', { desc = 'Pull [o]rigin (complete)' })
map('n', '<leader>gpp', '<cmd>Git pull<cr>', { desc = '[p]ull' })
map('n', '<leader>gpu', ':Git pull upstream ', { desc = 'Pull [u]pstream (complete)' })

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    -- vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    map('n', 'gD', vim.lsp.buf.declaration, { buffer = ev.buf, desc = "[g]o to [D]eclaration" })
    map('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf, desc = "[g]o to [d]efinition" })
    -- map('n', 'gh', vim.lsp.buf.document_highlights, { buffer = ev.buf, desc = "[g]et document [h]ighlights" })
    -- map('n', 'gs', vim.lsp.buf.document_symbols, { buffer = ev.buf, desc = "[g]et document [s]ymbols" })
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', 'gi', vim.lsp.buf.implementation, { buffer = ev.buf, desc = "[g]o to [i]mplementation" })
    map('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    map('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, { buffer = ev.buf, desc = "[wa] add workspace folder" })
    map('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, { buffer = ev.buf, desc = "[wr] remove workspace folder" })
    map('n', '<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, { buffer = ev.buf, desc = "[wl] list workspace folder" })
    map('n', '<leader>D', vim.lsp.buf.type_definition, { buffer = ev.buf, desc = "[D] show type definition" })
    map('n', '<leader>rn', vim.lsp.buf.rename, { buffer = ev.buf, desc = "[r]e[n]ame selection" })
    map({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, { buffer = ev.buf, desc = "perform [c]ode [a]ction" })
    map('n', 'gr', vim.lsp.buf.references, { buffer = ev.buf, desc = "[g]et [r]eferences" })
    map('n', '<leader>rf', function()
      vim.lsp.buf.format { async = true }
    end, { buffer = ev.buf, desc = "[r]un [f]ormat" })
  end,
})
