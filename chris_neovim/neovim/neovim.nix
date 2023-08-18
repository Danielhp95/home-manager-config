{ self, config, pkgs, lib, ... }:
let
  inherit (lib)
    concatStringsSep
    fold
    foldl'
    listToAttrs
    mkMerge
    mapAttrs
    mapAttrs'
    mapAttrsToList
    nameValuePair
    replaceStrings
    trace
    traceVal
    typeOf
    ;

  hlib = self.inputs.haumea.lib;

  luafiles = hlib.load {
    src = ./neovim;
    inputs = { inherit lib; };
    loader = [
      (hlib.matchers.extension "lua" hlib.loaders.path)
    ];
  };

  nameValuePairs = mapAttrsToList (name: value: { inherit name value; });

  flattenAttrsFileStructure = attrs:
    let
      recurse = root: foldl'
        (acc: item: #trace ("item ${builtins.toJSON item}\nacc: ${builtins.toJSON acc}")
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
    "vim-fugitive" = vim-fugitive;
    "vim-rhubarb" = vim-rhubarb;
    "nvim-autopairs" = nvim-autopairs;
    "nvim-surround" = nvim-surround;

    ## LSP
    "nvim-lspconfig" = nvim-lspconfig;
    "fidget.nvim" = fidget-nvim;
    "neodev.nvim" = neodev-nvim;
    "nvim-nu" = nvim-nu;
    "null-ls.nvim" = null-ls-nvim;
    "lsp_signature.nvim" = lsp_signature-nvim;
    # "mason.nvim" = mason-nvim;
    # "mason-lspconfig.nvim" = mason-lspconfig-nvim;

    ## cmp
    "nvim-cmp" = nvim-cmp;
    "cmp-cmdline" = cmp-cmdline;
    "cmp-buffer" = cmp-buffer;
    "cmp-path" = cmp-path;
    "cmp-nixpkgs" = cmp-nixpkgs;
    "cmp-rg" = cmp-rg;
    "cmp_luasnip" = cmp_luasnip;
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

    ## Git
    "gitlinker.nvim" = gitlinker-nvim;
    "gitsigns.nvim" = gitsigns-nvim;
    "Comment.nvim" = comment-nvim;

    ## General
    "sqlite.lua" = sqlite-lua;
    "vim-oscyank" = vim-oscyank;
    "toggleterm.nvim" = toggleterm-nvim;
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
    "telescope-tabs" = telescope-tabs;
    "telescope-env.nvim" = telescope-env;
    "telescope-undo.nvim" = telescope-undo;
    "telescope-changes.nvim" = telescope-changes;
    "telescope-all-recent.nvim" = telescope-all-recent;
    # telescope-ui-select-nvim  # use telescope for autocomplete

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

        # My all grammars breaks highlights for all languages, but this version doesn't have a working nushell treesitter :(
        # ${concatStringsSep "\n" (map (pkg:
          # ) nvim-treesitter-all.passthru.dependencies)

        # other attempts
          # ) treesitterWithParsers.passthru.dependencies)
          # ) (pkgs.vimPlugins.nvim-treesitter.overrideAttrs (oldAttrs: oldAttrs // {
          #   tree-sitter = pkgs.tree-sitter-full;
          # })).grammarPlugins)
        }
      '';
      # ${concatStringsSep "\n" (mapAttrsToList
      #   (name: pkg:
      # # ${concatStringsSep "\n" (map (pkg:
      #     "cp ${pkg}/parser/* $out/parser"
      #   # ) nvim-treesitter-all.passthru.dependencies)
      #   # ) treesitterWithParsers.passthru.dependencies)
      #   # ) pkgs.vimPlugins.nvim-treesitter.grammarPlugins)
      #   ) (pkgs.vimPlugins.nvim-treesitter.overrideAttrs (oldAttrs: oldAttrs // {
      #     tree-sitter = pkgs.tree-sitter-full;
      #   })).grammarPlugins)
      # }
      # ${concatStringsSep "\n" (mapAttrsToList
      #   (name: pkg:
      #     "cp ${pkg}/parser $out/parser/${replaceStrings [ "tree-sitter-" ] [ "" ] name}.so"
      #   ) pkgs.tree-sitter-full.passthru.builtGrammars)
      # }
      # ${concatStringsSep "\n" (map (pkg: lib.trace pkg.outPath
      #     "cp ${pkg}/parser/* $out/parser"
      # ) pkgs.tree-sitter-full.passthru.allGrammars)}
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

  # colors
  inherit (config.lib) base16;
  colorName = "base16-${base16.theme.scheme-slug}";
  vimColors = base16.programs.vim;
in
{
  home.packages = [ pkgs.zk ];
  home.sessionVariables."ZK_NOTEBOOK_DIR" = lib.mkDefault "/home/$USER/notes";
  # home.activation.neovim-copy = lib.mkForce (lib.hm.dag.entryBetween [ "reloadSystemd" ] [ ] "");
  programs.neovim = {
    enable = lib.mkForce true;
    extraPackages = with pkgs; [
      lua-language-server
      nil
      gopls
      nodePackages.bash-language-server
      nodePackages.pyright
      nodePackages.yaml-language-server
      nodePackages.dockerfile-language-server-nodejs
      docker-compose-language-service
      zk
    ];
    # nvim-treesitter
    # self.inputs.krafthome.vimPlugins.${pkgs.system}.nvim-treesitter-all
    # ] ++ (attrValues nvim-treesitter.grammarPlugins);
  };
  home.file = mkMerge [
    pluginFileLinks
    neovimFileLinks
    {
      ".config/nvim/colors/${colorName}.vim".source = vimColors.template "vim";
      ".config/nvim/autoload/airline-${colorName}.vim".source = base16.getTemplate "vim-airline-themes";
      ".config/nvim/parser/nu.so".source = "${pkgs.tree-sitter-full.builtGrammars.tree-sitter-nu}/parser";
    }
  ];

  themes.extra = {
    inherit luafiles neovimLinks;
  };
}
