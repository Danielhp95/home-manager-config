{pkgs, dsl, ...}:
with dsl;
{
  plugins = with pkgs.vimPlugins; [
   # pkgs.stylua
    #obsidian-nvim
  ];

  # setup.obsidian.callWith = {
  #   dir = "~/Documents/Obsidian Vault";
  #   completion = {
  #     nvim_cmp = true;
  #   };
  # };
  # lua = ''
  #   -- Allows gf to follow obsidian links
  #   vim.keymap.set(
  #     "n",
  #     "gf",
  #     function()
  #       if require('obsidian').util.cursor_on_markdown_link() then
  #         return "<cmd>ObsidianFollowLink<CR>"
  #       else
  #         return "gf"
  #       end
  #     end,
  #     { noremap = false, expr = true}
  #   )
  # '';
}
