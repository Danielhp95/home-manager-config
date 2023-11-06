local confdir = '~/.config/nvim/'
local nixplugdir = confdir .. 'nix-plugins/'

-- Use nix installed lazy.nvim
local lazypath = nixplugdir .. 'lazy.nvim'
vim.opt.rtp:prepend(lazypath)

-- Annoyingly, leader has to be mapped prior to loading lazy
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
require('lazy').setup('plugins', {
  -- set install directory to .config
  root = '~/.config/nvim/lazy-plugins',
  install = {
    -- TODO: maybe remove this install table entry
    -- do not install by default, note breaks lazy's nonlazy auto-installs
    -- missing = false,
  },
})

require 'options'
require 'aucmds'
require 'keybindings'
