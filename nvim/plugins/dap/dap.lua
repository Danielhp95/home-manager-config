local dap = require('dap')

-- Python
dap.adapters.python = {
  type = 'executable';
  command = "python";
  args = { '-m', 'debugpy.adapter' };
}

dap.configurations.python = {
  {
    type = 'python';
    request = 'launch';
    justMyCode = false;
    name = "Launch curent file";
    program = "${file}";
    pythonPath = "python";
    args = function()
      local args_string = vim.fn.input('Arguments: ')
      return vim.split(args_string, " +")
    end;
  },
  {
    type = 'python';
    request = 'launch';
    justMyCode = false;
    name = "Dart local on current yaml";
    program =  function()
      local yaml = vim.ui.input('Path to yaml: ')
      return "run_local " .. yaml
    end;
    pythonPath = "dart_local";
    args = function()
      local args_string = vim.fn.input('Arguments: ')
      return vim.split(args_string, " +")
    end;
  },
  {
    type = "python";
    request = "launch";
    justMyCode = false;
    name = "Find candidate policies";
    program = "apps/gt/scripts/eval_suite/find_candidate_policies.py";
    args = function()
      -- Index 0 indicates current file
      -- Do something like "run_local $file
      local args_string = vim.fn.input('Arguments: ', vim.api.nvim_buf_get_name(0))
      return vim.split(args_string, " +")
    end;
    pythonPath = "python";
  }
}

-- Lua
dap.configurations.lua = {
  {
    type = 'nlua',
    request = 'attach',
    name = "Attach to running Neovim instance",
    host = function()
      local value = vim.fn.input('Host [127.0.0.1]: ')
      if value ~= "" then
        return value
      end
      return '127.0.0.1'
    end,
    port = function()
      local val = tonumber(vim.fn.input('Port: '))
      assert(val, "Please provide a port number")
      return val
    end,
  }
}

dap.adapters.nlua = function(callback, config)
  callback({ type = 'server', host = config.host, port = config.port })
end
