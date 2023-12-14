local NixPlugin = require("helper").NixPlugin

-- handles `terminal.lua` action
local function handle_term(bufnr, action_type)
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  return function()
    actions.close(bufnr)
    local selection = action_state.get_selected_entry()
    local terminal = selection.value
    if type(terminal) ~= 'table' then return end

    local t = require('terminal')
    if action_type == 'open' then
      print(vim.inspect(terminal))
      t.set_target(terminal.index)
      t.open(terminal.index)
    elseif action_type == 'target' then
      t.set_target(terminal.index)
    else
      print('Unsupported action type: ' .. action_type)
    end
  end
end

-- queries `terminal.lua` for current terminals
local function telescope_terminals_finder ()
  return require("telescope.finders").new_table({
    results = require('terminal').get_terminal_ids(),
    entry_maker = function(t)
      local prefix_text = tostring(t.index) .. ": "
      local full_text = prefix_text .. t.term.title
      local bufinfo = vim.fn.getbufinfo(t.term.bufnr)
      return {
        value = t,
        -- req
        ordinal = full_text,
        display = full_text,
        path = t.term.title,
        lnum = bufinfo.lnum,
        bufnr = t.term.bufnr,
      }
    end,
  })
end

local function telescope_terminals_picker(opts)
  opts = opts or require("telescope.themes").get_dropdown()
  return require("telescope.pickers").new(opts, {
    prompt_title = "Terminals",
    finder = telescope_terminals_finder(),
    previewer = require('telescope.config').values.grep_previewer(opts),
    sorter = require("telescope.config").values.generic_sorter(opts),
    attach_mappings = function(bufnr, map)
      map("i", "<CR>", handle_term(bufnr, 'open'))
      map("n", "<CR>", handle_term(bufnr, 'open'))
      map("n", "<c-g>", handle_term(bufnr, 'target'))
      map("i", "<c-g>", handle_term(bufnr, 'target'))
      return true
    end,
  }):find()
end

return {
  {"rebelot/terminal.nvim", config = true},
  NixPlugin("voldikss/vim-floaterm"),
  NixPlugin("akinsho/toggleterm.nvim", { config = true }),
  NixPlugin("chomosuke/term-edit.nvim", {
    config = function()
      require('term-edit').setup({ prompt_end = '❯ ' })
    end
  }),
}
