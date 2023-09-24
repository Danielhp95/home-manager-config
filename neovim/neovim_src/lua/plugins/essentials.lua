local NixPlugin = require("helper").NixPlugin

local should_profile = os.getenv("NVIM_PROFILE")
if should_profile then
  require("profile").instrument_autocmds()
  if should_profile:lower():match("^start") then
    require("profile").start("*")
  else
    require("profile").instrument("*")
  end
end

local function toggle_profile()
  local prof = require("profile")
  if prof.is_recording() then
    prof.stop()
    vim.ui.input({ prompt = "Save profile to:", completion = "file", default = "profile.json" }, function(filename)
      if filename then
        prof.export(filename)
        vim.notify(string.format("Wrote %s", filename))
      end
    end)
  else
    prof.start("*")
  end
end
vim.keymap.set("", "<f1>", toggle_profile)

return {
  NixPlugin("bmichaelb/sniprun", { build = "bash install.sh" }),
  NixPlugin("numToStr/Comment.nvim", { opts = {} }),
  "sanfusu/neovim-undotree",
  NixPlugin("folke/which-key.nvim"),
  NixPlugin("windwp/nvim-autopairs", { event = "InsertEnter", opts = {} }),
  NixPlugin("nvim-tree/nvim-tree.lua", { opts = {} }),
  NixPlugin('kylechui/nvim-surround'),
  "stevearc/profile.nvim"
}
