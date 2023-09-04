local NixPlugin = require('helper').NixPlugin

local FmNvim = NixPlugin('is0n/fm-nvim')

-- keybindings
FmNvim.init = function ()
  local map = vim.keymap.set

  map('n', '<leader>-', '<cmd>lua FmDir("Ranger")<cr>', { desc = "Ranger open in current dir" })
  map('n', '<leader>_', 'Ranger ~', { desc = "Ranger open in home dir" })
  map('n', '<leader>ab', '<cmd>lua FmDir("Broot")<cr>', { desc = "[b]root open in curr dir" })
  map('n', '<leader>aD', '<cmd>Xplr ~<cr>', { desc = "Xplr open in home [D]ir" })
  map('n', '<leader>aB', '<cmd>lua FmDir("Broot")<cr>', { desc = "[B]root open in curr dir" })
  map('n', '<leader>ad', '<cmd>lua FmDir("Xplr")<cr>', { desc = "Xplr open in curr [d]ir" })
end

-- options
FmNvim.opts = {
  broot_conf = "~/.config/broot/conf.hjson",
  cmds = {
    broot = "broot --out /tmp/fm-nvim",
    ranger = "ranger",
    xplr = "xplr",
  },
  edit_cmd = "edit",
  mappings = {
    ESC = ":q<CR>",
    edit = "<C-e>",
    horz_split = "<C-h>",
    tabedit = "<C-t>",
    vert_split = "<C-v>",
  },
  ui = {
    default = "float",
    float = {
      blend = 0,
      border = "rounded",
      border_hl = "FloatBorder",
      float_hl = "Normal",
      height = 0.9,
      width = 0.9,
      x = 0.5,
      y = 0.5,
    }
  }
}

return { FmNvim }
