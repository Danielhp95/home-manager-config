local M = {}

M.nixplugdir = "~/.config/nvim/nix-plugins/"

-- returns a simple PluginSpec expecting plugin to be installed via nix
-- Arguement extra_plugin_spec will be added to the PluginSpec
M.NixPlugin = function(repo, extra_plugin_spec)
  extra_plugin_spec = extra_plugin_spec or {}
  local name = M.NameFromRepo(repo)
  local basic_table = { repo, name = name, dir = M.nixplugdir .. name }
  return M.mergeTables(basic_table, extra_plugin_spec)
end

-- For developing purposes
-- Prints table in nice format
M.P = function(v)
  print(vim.inspect(v))
  return v
end

M.mergeTables = function(table1, table2)
  for key, value in pairs(table2) do
    table1[key] = value
  end
  return table1
end

-- true if string is empty or nil
M.StrEmpty = function(s)
  return s == nil or s == ""
end

-- returns directory of current buffer file
M.GetCurrDir = function()
  file = vim.fn.expand("%")
  if M.StrEmpty(file) then
    return vim.fn.getcwd()
  else
    return vim.fn.system("dirname " .. file):gsub("%s+", "")
  end
end

-- call fm-nvim on current directory
M.FmDir = function(cmd)
  local parent = M.GetCurrDir()
  vim.cmd(string.format(":%s %s", cmd, parent))
end

-- transforms `project/name` -> `name`
M.NameFromRepo = function(repo)
  return repo:match("/(.-)$")
end

return M
