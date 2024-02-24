local NixPlugin = require("helper").NixPlugin

-- TODO: use `gevent=true` to bypass the issue with fetching data forever on `aws s3`` calls
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

        justMyCode=false,
        program = "${file}", -- This configuration will launch the current file if used.
        pythonPath = (os.getenv("VIRTUAL_ENV") or '') .. "/bin/python",
        gevent=true,
        subProcess=true
      },
      {
        type = "python",
        request = 'launch',
        name = "run_local",
        cwd = vim.loop.cwd(),
        logToFile = true,
        program = "/home/dev/venv/bin/dart",
        args = {
          "run_local",
          "-m",
          "both",
          "${file}"
        },
      }
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
  end
}

return Dap
