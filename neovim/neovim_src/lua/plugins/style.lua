local NixPlugin = require("helper").NixPlugin

local ColorSchemes = NixPlugin("navarasu/onedark.nvim")
local LuaLine = NixPlugin("nvim-lualine/lualine.nvim")
local IndentLines = NixPlugin("lukas-reineke/indent-blankline.nvim")
local BufferLine = NixPlugin("akinsho/bufferline.nvim")

BufferLine.opts = {
  options = {
    -- Remove close icons as I never use them
    separator_style = 'slope',
    buffer_close_icon = '',
    close_icon = '',
  }
}

ColorSchemes.dependencies = {
  NixPlugin("EdenEast/nightfox.nvim"),
  NixPlugin("nvim-tree/nvim-web-devicons"),
}

ColorSchemes.config = function()
  require("onedark").setup({ style = "deep", toggle_style_key = "<C-q>" })
  vim.api.nvim_command("colorscheme carbonfox")
end

IndentLines.dependencies = {
  "TheGLander/indent-rainbowline.nvim", -- This plugin is used to make configuratino for indent-blankline.nvim
}

IndentLines.opts = {
  char = "┊",
  show_trailing_blankline_indent = false,
  show_current_context = true,
  -- This should be handled by plugin indent-rainbowline
  char_highlight_list = { "SpecialKey" },
}

-- Status Bar
LuaLine.opts = {
  options = {
    icons_enabled = true,
    theme = "auto",
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    globalstatus = false,
  },
  sections = {
    lualine_a = { "%{&spell ? 'SPELL' : ':3'}", "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { "filename" },
    lualine_x = { "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = { "filetype" },
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = {},
}

return {
  ColorSchemes,
  LuaLine,
  IndentLines,
  BufferLine
}
