local M = require('helper').NixPlugin('akinsho/toggleterm.nvim')

M.init = function ()
  local map = vim.keymap.set

  -- toggleterm
  map('t', '<C-S>', '<C-\\><C-n> :ToggleTerm<cr>', {noremap = true})
  map('t', '<C-\\><C-n>', '<Esc>', {noremap = true})
  map('t', '<Esc>', '<C-\\><C-n>', {noremap = true})
end

M.opts = {
  open_mapping = [[<C-S>]],
  direction = "float",
  float_opts = {
    border = "double",
    winblend = 0,
  },
  persist_mode = true,
  persist_size = true,
  shade_terminals = true,
  shading_factor = 2,
  start_in_insert = true,
}

return { M }
