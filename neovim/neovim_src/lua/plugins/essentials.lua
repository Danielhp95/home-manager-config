local NixPlugin = require("helper").NixPlugin

local Comment = NixPlugin("numToStr/Comment.nvim")

Comment.opts = {}

return {
  Comment,
  "sanfusu/neovim-undotree",
  NixPlugin("folke/which-key.nvim"),
  NixPlugin("windwp/nvim-autopairs", { event = "InsertEnter", opts = {} }),
  NixPlugin("nvim-tree/nvim-tree.lua", { opts = {} }),
  NixPlugin('kylechui/nvim-surround')
}

-- which-key-nvim
