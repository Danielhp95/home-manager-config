local NixPlugin = require("helper").NixPlugin

-- Look into this to have pytest integration https://github.com/mfussenegger/nvim-dap-python
local Dap = {
  url = 'https://github.com/mfussenegger/nvim-dap',
  dependencies = {
    'theHamsta/nvim-dap-virtual-text',
    "rcarriga/nvim-dap-ui"
  },
  -- opts = {},
  config = function()
    local dap = require('dap')
    -- Python
    dap.adapters.python = {
      type = 'executable',
      command = "python",
      args = { '-m', 'debugpy.adapter' },
    }

    dap.configurations.python = {
      {
        -- The first three options are required by nvim-dap
        type = 'python', -- the type here established the link to the adapter definition: `dap.adapters.python`
        request = 'launch',
        name = "Launch file",
        -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

        program = "${file}", -- This configuration will launch the current file if used.
        pythonPath = (os.getenv("VIRTUAL_ENV") or '') .. "/bin/python"
      },
    }

    require('dapui').setup({
      layouts = {
        {
          elements = {
            -- Elements can be strings or table with id and size keys.
            { id = "scopes", size = 0.25, },
            "breakpoints",
            "stacks",
            "watches",
          },
          size = 0.3,
          position = "left",
        },
        {
          elements = {
            "repl",
          },
          size = 0.25,
          position = "bottom",
        }
      },
    })
    -- TODO: still needs dap.configurations.python?
  end
}

return Dap
