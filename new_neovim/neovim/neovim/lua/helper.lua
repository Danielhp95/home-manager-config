local M = {}

M.nixplugdir = '~/.config/nvim/nix-plugins/'

-- true if string is empty or nil
M.StrEmpty = function (s)
  return s == nil or s == ""
end

-- returns directory of current buffer file
M.GetCurrDir = function ()
  file = vim.fn.expand("%")
  if M.StrEmpty(file) then
    return vim.fn.getcwd()
  else
    return vim.fn.system("dirname "..file):gsub("%s+", "")
  end
end

-- call fm-nvim on current directory
M.FmDir = function (cmd)
  parent = M.GetCurrDir()
  vim.cmd (string.format(":%s %s", cmd, parent))
end

-- transforms `project/name` -> `name`
M.NameFromRepo = function (repo)
  return repo:match('/(.-)$')
end

-- returns a simple PluginSpec expecting plugin to be installed via nix
M.NixPlugin = function (repo)
  local name = M.NameFromRepo(repo)
  return { repo, name = name, dir = M.nixplugdir .. name }
end

return M
