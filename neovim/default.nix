{ inputs, config, pkgs, lib, ... }:
let
  inherit (lib)
    concatStringsSep
    foldl'
    listToAttrs
    mkMerge
    mapAttrs'
    mapAttrsToList
    nameValuePair
    ;

  hlib = inputs.haumea.lib;

  luafiles = hlib.load {
    src = ./neovim_src;
    inputs = { inherit lib; };
    loader = [
      (hlib.matchers.extension "lua" hlib.loaders.path)
    ];
  };

  nameValuePairs = mapAttrsToList (name: value: { inherit name value; });

  flattenAttrsFileStructure = attrs:
    let
      recurse = root: foldl'
        (acc: item:
          (if (builtins.typeOf item.value) == "set" then
            acc ++ (recurse "${root}/${item.name}" (nameValuePairs item.value))
          else
            acc ++ [{ name = "${root}/${item.name}.lua"; value = item.value; }]
          )
        ) [ ];
    in
    recurse "" (nameValuePairs attrs)
  ;

  neovimLinks = listToAttrs (flattenAttrsFileStructure luafiles);
  neovimFileLinks = mapAttrs' (path: source: nameValuePair ".config/nvim${path}" { inherit source; }) neovimLinks;

  treesitterWithParsers = pkgs.vimPlugins.nvim-treesitter.withPlugins (_: pkgs.tree-sitter-full.allGrammars);

  plugins = with pkgs.vimPlugins; {
    ## Core
    "lazy.nvim" = lazy-nvim;
    "vim-rhubarb" = vim-rhubarb;
    "nvim-autopairs" = nvim-autopairs;
    "nvim-surround" = nvim-surround;
    "Comment.nvim" = comment-nvim;
    "undotree" = undotree;
    "nvim-tree.lua" = nvim-tree-lua;

    ## Git
    "vim-fugitive" = vim-fugitive;
    "diffview.nvim" = diffview-nvim;

    ## LSP
    "nvim-lspconfig" = nvim-lspconfig;  # Top level LSP configuration
    "fidget.nvim" = fidget-nvim;  # 
    "neodev.nvim" = neodev-nvim;  # Lua LSP
    "lsp_signature.nvim" = lsp_signature-nvim;  # Show function signature
    "lspsaga" = lspsaga-nvim; # extra UI for lsp

    ## cmp
    "nvim-cmp" = nvim-cmp;
    "cmp-cmdline" = cmp-cmdline;
    "cmp-buffer" = cmp-buffer;
    "cmp-path" = cmp-path;
    "cmp-rg" = cmp-rg;
    "cmp_luasnip" = cmp_luasnip;
    "compe-latex-symbols" = compe-latex-symbols;
    "LuaSnip" = luasnip;
    "cmp-nvim-lsp" = cmp-nvim-lsp;
    "friendly-snippets" = friendly-snippets;
    "lspkind.nvim" = lspkind-nvim;

    ## UI
    "plenary.nvim" = plenary-nvim;
    "lualine.nvim" = lualine-nvim;
    "which-key.nvim" = which-key-nvim;
    "fm-nvim" = fm-nvim;
    "wilder.nvim" = wilder-nvim;
    "cpsm" = cpsm;
    "nvim-web-devicons" = nvim-web-devicons;
    "nvim-colorizer.lua" = nvim-colorizer-lua;
    "indent-blankline.nvim" = indent-blankline-nvim;
    "bufferline.nvim" = bufferline-nvim;
    "trouble.nvim" = trouble-nvim;

    ## Git
    "gitlinker.nvim" = gitlinker-nvim;
    "gitsigns.nvim" = gitsigns-nvim;

    ## General
    "sqlite.lua" = sqlite-lua;
    "vim-oscyank" = vim-oscyank;
    "toggleterm.nvim" = toggleterm-nvim;
    "vim-floaterm" = vim-floaterm;
    "term-edit.nvim" = term-edit-nvim;
    "sniprun" = sniprun;

    "suda.vim" = suda-vim;
    "vim-togglelist" = vim-togglelist;
    "nvim-bqf" = nvim-bqf;
    "fzf" = pkgs.fzf;
    "zk-nvim" = zk-nvim;

    ## Telescope
    "telescope.nvim" = telescope-nvim;
    "telescope-fzf-native.nvim" = telescope-fzf-native-nvim;
    "telescope-file-browser.nvim" = telescope-file-browser-nvim;
    "telescope-manix" = telescope-manix; # nix manix search
    "telescope-cheat.nvim" = telescope-cheat-nvim; # cheatsheet search
    "telescope-live-grep-args.nvim" = telescope-live-grep-args-nvim;  # Being able to pass arguments for ripgrep (used by live grep in Telescope)
    # "telescope-tabs" = telescope-tabs;  # TODO: maybe add?
    # "telescope-env.nvim" = telescope-env;  # TODO: Add later
    "telescope-undo.nvim" = telescope-undo-nvim;
    # "telescope-changes.nvim" = telescope-changes;
    # "telescope-all-recent.nvim" = telescope-all-recent;
    # telescope-ui-select-nvim  # use telescope for autocomplete

    # colorscheme
    "onedark.nvim" = onedark-nvim;
    "nightfox.nvim" = nightfox-nvim;

    ## Treesitter
    "nvim-treesitter-textobjects" = nvim-treesitter-textobjects;
    "nvim-treesitter-context" = nvim-treesitter-context;
    "nvim-treesitter-refactor" = nvim-treesitter-refactor;
    "playground" = playground;
    "nvim-treesitter" = (nvim-treesitter.overrideAttrs (oldAttrs: oldAttrs // {
      tree-sitter = pkgs.tree-sitter-full;
    })).withAllGrammars;
    # "nvim-treesitter" = nvim-treesitter.withAllGrammars;
    # workaround required for using nvim-treesitter with `lazy.nvim`
    "nvim-treesitter-parsers" = pkgs.stdenv.mkDerivation {
      name = "nvim-treesitter-parsers";
      src = pkgs.vimPlugins.nvim-treesitter.grammarPlugins.ada;
      buildPhase = ''
        mkdir -p $out/parser
        ${concatStringsSep "\n" (mapAttrsToList
          (name: pkg:
            "cp ${pkg}/parser/* $out/parser"
          ) pkgs.vimPlugins.nvim-treesitter.grammarPlugins)
        }
      '';
    };
  };

  pluginFileLinks = mapAttrs'
    (name: pkg:
      nameValuePair ".config/nvim/nix-plugins/${name}" {
        source = pkg;
        # recursive = true;
      })
    plugins;

  treesitterParsers = mapAttrs'
    (name: pkg:
      nameValuePair ".config/nvim/parser/${name}" {
        source = "${pkg}/parser/${name}.so";
      })
    pkgs.vimPlugins.nvim-treesitter.grammarPlugins;
in
{
  programs.neovim = {
    enable = lib.mkForce true;
    extraPackages = with pkgs; [
      lua-language-server
      nil
      gopls
      stylua
      yamlfmt
      nixpkgs-fmt
      python310Packages.gevent
      nodePackages.bash-language-server
      nodePackages.pyright
      inputs.basedpyright-nix.packages.x86_64-linux.default  # basedpyright. Better version of pyright
      nodePackages.yaml-language-server
      nodePackages.dockerfile-language-server-nodejs
      docker-compose-language-service
      libgit2
    ];
  };
  home.file = mkMerge [
    pluginFileLinks
    neovimFileLinks
  ];
}
