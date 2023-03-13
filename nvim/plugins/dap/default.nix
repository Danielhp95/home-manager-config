# Git in vim plugin from tpope
{ pkgs, dsl, ... }:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
    nvim-dap # Core
    nvim-dap-ui # To have a modular IntelliJ style UI
    nvim-dap-virtual-text # To show realized variable values
    telescope-dap-nvim

    # Python
    pkgs.python310Packages.debugpy # TODO: Should this be installed in Python projects instead of system-wide like here?

    # Lua
    #one-small-step-for-vimkind
  ];

  use.dapui.setup = callWith {
    layouts = [
      { elements = [
        # Elements can be strings or table with id and size keys.
          { id = "scopes"; size = 0.25; }
          "breakpoints"
          "stacks"
          "watches"
        ];
        size = 0.3;
        position = "left";
      }
      { elements = [
          "repl"
        ];
        size = 0.25;
        position = "bottom";
      }
    ];
  };
  setup.nvim-dap-virtual-text = callWith { };

  lua = builtins.readFile ./dap.lua;
}
