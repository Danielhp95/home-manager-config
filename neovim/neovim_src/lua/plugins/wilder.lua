local NixPlugin = require("helper").NixPlugin

local Wilder = NixPlugin("gelguy/wilder.nvim", {
  dependencies = {
    NixPlugin("nixprime/cpsm"),
  },
  build = ":UpdateRemotePlugins",

  config = function()
    -- Straight from https://github.com/gelguy/wilder.nvim
    local wilder = require("wilder")
    wilder.setup({
      modes = { ":", "/", "?" },
      previous_key = "<C-k>",
      next_key = "<C-j>",
      accept_key = "<C-Space>",
      reject_key = "<C-e>",
    })

    wilder.set_option("pipeline", {
      wilder.branch(
        wilder.python_file_finder_pipeline({
          file_command = function(ctx, arg)
            if string.find(arg, ".") ~= nil then
              return { "fd", "-tf", "-H" }
            else
              return { "fd", "-tf" }
            end
          end,
          path = "", -- Search on current directory
          dir_command = { "fd", "-td" },
          filters = { "cpsm_filter" },
        }),
        wilder.substitute_pipeline({
          pipeline = wilder.python_search_pipeline({
            skip_cmdtype_check = 1,
            pattern = wilder.python_fuzzy_pattern({
              start_at_boundary = 0,
            }),
          }),
        }),
        wilder.cmdline_pipeline({
          fuzzy = 2,
        }),
        {
          wilder.check(function(ctx, x)
            return x == ""
          end),
          wilder.history(),
        },
        wilder.python_search_pipeline({
          pattern = wilder.python_fuzzy_pattern({
            start_at_boundary = 0,
          }),
        })
      ),
    })
    local popupmenu_renderer = wilder.popupmenu_renderer(wilder.popupmenu_palette_theme({
      border = "rounded",
      empty_message = wilder.popupmenu_empty_message_with_spinner(),
      highlighter = {
        wilder.pcre2_highlighter(),
        wilder.basic_highlighter(),
      },
      left = {
        " ",
        wilder.popupmenu_devicons(),
        wilder.popupmenu_buffer_flags({
          flags = " a + ",
          icons = { ["+"] = "", a = "", h = "" },
        }),
      },
      right = {
        " ",
        wilder.popupmenu_scrollbar(),
      },
    }))

    local wildmenu_renderer = wilder.wildmenu_renderer({
      separator = " · ",
      left = { " ", wilder.wildmenu_spinner(), " " },
      right = { " ", wilder.wildmenu_index() },
    })

    wilder.set_option(
      "renderer",
      wilder.renderer_mux({
        [":"] = popupmenu_renderer,
        ["/"] = popupmenu_renderer,
        substitute = wildmenu_renderer,
      })
    )
  end
})

return { Wilder }
