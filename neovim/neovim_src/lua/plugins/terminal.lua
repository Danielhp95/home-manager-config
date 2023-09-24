local NixPlugin = require("helper").NixPlugin


return { NixPlugin("voldikss/vim-floaterm"), NixPlugin("akinsho/toggleterm.nvim", { config = true }) }
