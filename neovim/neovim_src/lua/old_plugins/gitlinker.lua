local NixPlugin = require('helper').NixPlugin
local M = NixPlugin('ruifm/gitlinker.nvim')

M.dependencies = {
  NixPlugin('ojroques/vim-oscyank')
}

M.config = function ()
  local gitlinker = require('gitlinker')

  gitlinker.setup({
    callbacks = {
      ["gitea.home.lan"] = require "gitlinker.hosts".get_gitea_type_url,
      ["gitea.media.cave"] = require "gitlinker.hosts".get_gitea_type_url,
    },
    opts = {
      action_callback = function(url)
        -- yank to unnamed register
        vim.api.nvim_command('let @" = \'' .. url .. '\'')
        -- copy to the system clipboard using OSC52
        vim.fn.OSCYank(url)
      end,
    },
  })

  -- keybindings
  local map = vim.keymap.set
  local open_in_browser = function (mode)
    return function ()
      gitlinker.get_buf_range_url(mode, {action_callback = require"gitlinker.actions".open_in_browser})
    end
  end

  -- copy url of current buffer
  map('n', '<leader>gyy', gitlinker.get_buf_range_url, { silent = true, noremap = true, desc = 'Copy URL of current buffer' })
  map('v', '<leader>gyy', gitlinker.get_buf_range_url, { silent = true, noremap = true, desc = 'Copy URL of current buffer' })

  -- open current buffer url in browser
  map('n', '<leader>gyb', open_in_browser('n'), { silent = true, noremap = true, desc = 'Open current buffer in browser' })
  map('v', '<leader>gyb', open_in_browser('v'), { silent = true, desc = 'Open current buffer in browser' })

  -- copy/open repo homepage/git url
  map('n', '<leader>gyB', function ()
    gitlinker.get_repo_url({action_callback = require"gitlinker.actions".open_in_browser})
  end, { silent = true, desc = 'Open Repo URL in browser' })
  map('n', '<leader>gyr', gitlinker.get_repo_url, { silent = true, desc = 'Copy Repo URL' })

end

return { M }
