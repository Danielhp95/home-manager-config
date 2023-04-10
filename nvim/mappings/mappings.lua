local wk = require('which-key')

-- Miscelaneous small quality of life stuff
wk.register({
  H = {"<cmd>tabp<cr>", "Previous tab"},
  L = {"<cmd>tabn<cr>", "Next tab"},
  ["<C-Up>"] = {"<cmd>resize -1<cr>", "Continuous window vertical resize"},
  ["<C-Down>"] = {"<cmd>resize +1<cr>", "Continuous window vertical resize"},
  ["<C-Left>"] = {"<cmd>vertical resize +1<cr>", "Continuous window horizontal resize"},
  ["<C-Right>"] = {"<cmd>vertical resize -1<cr>", "Continuous window horizontal resize"},
  ['<leader>nw'] = {
    name = '+[n]o',
    w = {"<cmd>set wrap!<cr>", "line [w]rap"},
    h = {"<cmd>noh<cr>", "[h]ighlight"},
  },
  ["<C-s><C-s>" ] = {"<cmd>w<cr>", "[s]ave buffer"},
  ["gf"] = {"<cmd>e <cfile><cr>", "[g]o to [f]ile under cursor even if not existing"},
})

-- Git
wk.register({
  ['<leader>'] = {
    g = {
      name = "[g]it",
      s = {"<cmd>Git<cr>", "Git [s]tatus half screen"},
      S = {"<cmd>Gtabedit :<cr>", "Git [S]tatus new tab"},
      a = {"<cmd>Git add %:p<cr>", "Git [a]dd file"},
      c = {"<cmd>Git commit<cr>", "Git [c]ommit"},
      t = {"<cmd>Gitsigns toggle_signs<cr>", "[t]oggle gitsigns"},
      r = {"<cmd>Gread<cr>", "[r]evert to latest git version"},
      b = {"<cmd>Gitsigns blame_line<cr>", "[b]lame current line"},
      d = {
        name = "+[d]iff",
        t = {"<cmd>DiffviewToggleFiles<cr>", "[t]oggle diff files"},
        r = {"<cmd>DiffviewRefresh<cr>", "[r]efresh git merge state"},
        o = {"<cmd>DiffviewOpen<cr>", "[o]pen new tab with diff merger"},
        c = {"<cmd>DiffviewClose<cr>", "[c]lose diff merger"},
      },
      -- Do something about blame lines?
      l = {
        name = "+[l]og",
        r = {"<cmd>0Gclog<cr>", "Load all [r]evisions of this file for each commit that affects it"},
        d = {"<cmd>Gclog<cr>", "Load all [d]iffs of this file for each commit"},
      },
      h = {
        name = "+[h]unks",
        s = {"<cmd>lua require('gitsigns').preview_hunk()<CR>", "[s]how hunk diff"},
        a = {"<cmd>Gitsigns stage_hunk<CR>", "St[a]ge hunk"},
        u = {"<cmd>Gitsigns undo_stage_hunk<CR>", "[U]ndo stage hunk"},
        n = {"<cmd>lua require('gitsigns').next_hunk({wrap = true})<CR>", "[n]ext hunk"},
        p = {"<cmd>lua require('gitsigns').prev_hunk({wrap = true})<CR>", "[p]revious hunk"},
      },
    }
  }
})

-- Telescope
wk.register({
  ['<leader>'] = {
    t = {
      name = '[t]elescope',
      f = {"<cmd>Telescope find_files<CR>", "Find [f]iles"},
      g = {"<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>", "Live [g]rep"},
      b = {"<cmd>Telescope buffers<CR>", "[b]uffers"},
      h = {"<cmd>Telescope help_tags<CR>", "NVIM [h]elp"},
      k = {"<cmd>Telescope keymaps<CR>", "[k]eymaps"},
      p = {"<cmd>Telescope project<CR>", "[p]rojects"},
      o = {"<cmd>Telescope oldfiles<CR>", "Last [o]pened files"},
      t = {"<cmd>Telescope<CR>", "Default [t]elescope"},
      r = {"<cmd>Telescope resume<CR>", "[r]esume last search"},
      s = {"<cmd>Telescope lsp_document_symbols<CR>", "Buffer lsp [s]ymbols"},
      S = {"<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", "Workspace lsp [S]ymbols"},
      d = {"<cmd>lua require'telescope.builtin'.find_files({cwd='~/configs'})<cr>", "Open NIX config [d]irectory"},
      v = {"<cmd>lua require'telescope.builtin'.find_files({cwd='~/Documents/Obsidian Vault/'})<cr>", "Open Obsidian [v]ault"},
      q = {"<cmd>lua require'telescope.action'.send_to_qflist()<cr>", "Send search results to [q]uickfix list"},
    },
  }
})

-- Spelling
wk.register({
  ['<leader>'] = {
    s = {
      name = '[s]pelling',
      n = {"]s", "[n]ext spelling error"},
      p = {"[s", "[p]revious spelling error"},
      s = {"<cmd>lua require('telescope.builtin').spell_suggest(require('telescope.themes').get_cursor())<cr>", "[s]uggestion"},
      a = {"zg", "[a]dd to dictionary"},
      t = {"<cmd>set spell!<cr>", "[t]oggle spell check"}
    }
  }
})

-- Diagnostics
wk.register({
  ['<leader>'] = {
    d = {
      name = '[d]iagnostics',
      n = {'<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>', "[n]ext diagnostic"},
      p = {'<cmd>lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>', "[p]revious diagnostic"},
      s = {"<cmd>lua vim.diagnostic.open_float()<CR>", "[s]how diagnostic under cursor"},
      b = {"<cmd>TroubleToggle document_diagnostics<CR>", "[b]uffer diagnostics"},
      P = {"<cmd>TroubleToggle workspace_diagnostics<CR>", "all [P]roject diagnostics"},
    }
    -- Recall that in Trouble pop-up thingy there's a keymap of "m" to change between document and workspace diagnostics
  }
})

-- Comments
wk.register({
  ['<leader>'] = {
      c = {
        name = '[c]omments',
        l = {"<cmd>lua require('Comment.api').toggle.linewise.current()<cr>", "[l]inewise comment"},
        b = {"<cmd>lua require('Comment.api').toggle.blockwise.current()<cr>", "[b]lockwise comment"},
    }
  }
})


-- LSP
local vertical_layout = "{layout_strategy='vertical', layout_config = {mirror = true}}"
wk.register({
  K = {"<cmd>lua vim.lsp.buf.hover()<CR>", "Show do[k]umentation"},
  ['<c-k'] = {"<cmd>lua vim.lsp.buf.signature_help()<CR>", "Show signature help"}, -- TODO: Not working
  ['<leader>'] = {
    l = {
      name = '[l]sp',
      d = {string.format("<cmd>lua vim.lsp.buf.definition(%s)<CR>", vertical_layout), "Go to [d]efinition"},
      D = {string.format("<cmd>lua vim.lsp.buf.declaration(%s)<CR>", vertical_layout), "Go to [D]eclaration"},
      i = {string.format("<cmd>lua vim.lsp.buf.implementation(%s)<CR>", vertical_layout), "Go to [i]mplementation"},
      r = {string.format("<cmd>Trouble lsp_references<cr>", vertical_layout), "Show [r]eferences"},
      n = {string.format("<cmd>Lspsaga rename<cr>", vertical_layout), "Re[n]ame"},
      f = {string.format("<cmd>lua vim.lsp.buf.format()<cr>", vertical_layout), "[F]ormat file"},
      R = {string.format("<cmd>LspRestart<cr>", vertical_layout), "[R]estart LSP"},
    },
  }
})
wk.register({
    ['<leader>l'] = {
        name = 'LSP',
        c = {"<cmd>lua vim.lsp.buf.code_action()<CR>", "[c]ode actions"}},
    },
    {mode = 'v'}
)

-- FM-nvim
wk.register({
  ['<leader>'] = {
    ['-'] = {"<cmd>Ranger %:p:h<cr>", "Ranger open in current dir"},
    ['_'] = {"<cmd>Ranger ~<cr>", "Ranger open in home dir"},
  }
})

-- Debugger
-- TODO: look at set_exception_breakpoint. Looks pretty sweet
wk.register({
  ['<leader>'] = {
    b = {
      name = 'De[b]ugger',
      t = {"<cmd>lua require('dapui').toggle(2)<cr>", "[t]oggle debugger repl"},
      T = {"<cmd>lua require('dapui').toggle()<cr>", "[T]oggle all debugger UIs"},
      b = {"<cmd>DapToggleBreakpoint<cr>", "[b]reakpoint toggle current line"},
      B = {"<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", "[B]reakpoint with condition"},
      e = {"<cmd>lua require('dapui').eval()<cr>", "[e]valuate expresion"},

      c = {"<cmd>DapContinue<cr>", "Start / [c]ontinue debugger"},
      i = {"<cmd>lua require'dap'.terminate()<cr>", "[i]nterrupt debugger session"},

      n = {"<cmd>lua require'dap'.step_over({askForTargets = true})<CR>", "Step over ([n]ext)"},
      s = {"<cmd>lua require'dap'.step_into()<CR>", "[s]tep into"},
      o = {"<cmd>lua require'dap'.step_out()<CR>", "Step [o]ut"},
      u = {"<cmd>lua require'dap'.up()<CR>", "[u]p stacktrace"},
      d = {"<cmd>lua require'dap'.down()<CR>", "[d]own stacktrace"},
      -- GOTO?

      l = {
        name = '+[l]ist',
        c = {"<cmd>Telescope dap commands<cr>", "[c]ommands"},
        b = {"<cmd>Telescope dap list_breakpoints<cr>", "[b]reakpoints"},
        v = {"<cmd>Telescope dap variables<cr>", "[v]ariables"},
        f = {"<cmd>Telescope dap frames<cr>", "[f]rames"},
        C = {"<cmd>Telescope dap configurations<cr>", "[C]onfigurations"},
      }
    }
  }
})

-- Debugger: visual
wk.register(
  {
    ['<leader>b'] = {
      name = 'de[b]ugger',
      e = {"<cmd>lua require('dapui').eval()<cr>", "[e]valuate expresion"}, }
  },
  {mode = 'v'}
)

-- ToggleTerm
wk.register({
  ['<leader><leader>'] = {
    name = '[t]erminal',
    ['z'] = {"<cmd>NeoZoomToggle<cr>", "[z]oom current buffer"},
    ['f'] = {"<cmd>ToggleTerm direction='float'<cr>", "[f]loating terminal"},
    ['v'] = {"<cmd>ToggleTerm direction='vertical' size=50<cr>", "[v]ertical terminal"},
    ['h'] = {"<cmd>ToggleTerm direction='horizontal'<cr>", "[h]orizontal terminal"},
    ['t'] = {"<cmd>ToggleTermToggleAll<cr>", "Toggle all [t]erminals"},
  }
})


-- Development
wk.register({
  ['<C-s><C-r>'] = {"<cmd>source %<cr>", "[s]ources cu[r]renty file"}
})

-- pandoc
wk.register({
  ['<leader><leader>p'] = {
    "<cmd>!pandoc -t beamer ~/configs/dotfiles/nvim/pandoc_header % --from=markdown --pdf-engine=lualatex --output=%:r.pdf<cr>",
    "[p]andoc file into PDF presentation"}
})
