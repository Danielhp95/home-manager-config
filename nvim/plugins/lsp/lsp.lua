local null_ls = require("null-ls")

-- Paths are defined in nvim/plugins/lsp/default.nix
null_ls.setup({
  sources = {
      -- Ruff: Python linter
      null_ls.builtins.formatting.ruff.with({ command = ruff_path }),
      --null_ls.builtins.diagnostics.ruff.with({ command = ruff_path }),

      -- Black: Python formatter
      null_ls.builtins.formatting.black.with({ command = black_path }),

      --Lua formatter
      null_ls.builtins.formatting.stylua.with({ command = stylua_path }),
  },
})
