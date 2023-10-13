local NixPlugin = require("helper").NixPlugin


return {
  NixPlugin("voldikss/vim-floaterm"),
  NixPlugin("akinsho/toggleterm.nvim", { config = true }),
  NixPlugin("chomosuke/term-edit.nvim", {
    config = function()
      require('term-edit').setup({ prompt_end = '❯ ' })
    end
  }),
}
