local NixPlugin = require('helper').NixPlugin

-- cmp_luasnip will not start without nvim-cmp as a dependency when imported from nix
local zk = NixPlugin('mickael-menu/zk-nvim')
zk.config = function ()
  require ('zk').setup {
    picker = "telescope",
    lsp = {
      -- `config` is passed to `vim.lsp.start_client(config)`
      config = {
        cmd = { "zk", "lsp" },
        name = "zk",
        -- on_attach = ...
        -- etc, see `:h vim.lsp.start_client()`
      },

      -- automatically attach buffers in a zk notebook that match the given filetypes
      auto_attach = {
        enabled = true,
        filetypes = { "markdown" },
      },
    },
  }
end
return {
  zk,
}
