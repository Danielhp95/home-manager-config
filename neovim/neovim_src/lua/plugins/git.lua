local NixPlugin = require('helper').NixPlugin

return {
  NixPlugin('tpope/vim-fugitive'),
  -- NixPlugin('lewis6991/gitsigns.nvim', { opts = {} }),
  NixPlugin('sindrets/diffview.nvim'),
}
