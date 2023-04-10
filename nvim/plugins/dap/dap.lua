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
  -- The config below does not work
  -- It correclty access the run_local command in dart. but it fails in dart_client/util.py:git_repo_root()
  {
    name = "Dart run_local";
    type = 'python';
    request = 'launch';
    justMyCode = false;
    python = "python";
    program = "/home/dev/.local/bin/dart";
    args = {"run_local", "--mode", "both", "/home/dev/sai/apps/spiderman/run_configs/spiderman.jsonnet"};
  },
  {
    name = "Dart run_local 2";
    type = 'python';
    request = 'launch';
    justMyCode = false;
    code = "import dart_client.cli; dart_client.cli.run_local({\"config\": \"/home/dev/sai/apps/spiderman/run_configs/spiderman.jsonnet\", \"mode\": \"both\"})";
    python = "python";
  },
}

-- Lua: Not working
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
