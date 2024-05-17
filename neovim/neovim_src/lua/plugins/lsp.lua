-- Here we do two things:
-- (1) Set up the configuration for packages used in the declaration of LSPs
-- (2) Call lspconfig.config function, which sets all the individual LSPs
local NixPlugin = require("helper").NixPlugin

-- Formmater
local Conform = {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			-- Conform will run multiple formatters sequentially
			python = { "black", "ruff" },
			yaml = { "yamlfmt" },
			nix = { "nixpkgs-fmt" },
		},
	},
}

-- LUA
-- Additional lua configuration, makes nvim stuff amazing!
local neodev = NixPlugin("folke/neodev.nvim", {
	lazy = true,
	opts = {
		library = {
			enabled = true,
			runtime = true,
			types = true,
			plugins = true,
		},
		setup_jsonls = true,
		lspconfig = true,
	},
})

-- LSP Configuration & Plugins
local lspconfig_toplevel = {
  "neovim/nvim-lspconfig",
	dependencies = {
		-- Useful status updates for LSP
		NixPlugin("j-hui/fidget.nvim", { event = "LspAttach", opts = {} }),
		NixPlugin("ray-x/lsp_signature.nvim"),
		NixPlugin("folke/neodev.nvim"),
	},
	config = function()
		local lspconfig = require("lspconfig")

		-- PYTHON
		-- Try basedpyright in the future, it did not work for me (could not read pyproject.toml)
		lspconfig.pyright.setup(
		{
			cmd = { "pyright-langserver", "--stdio"},
			root_dir = lspconfig.util.find_git_ancestor,

			capabilities = vim.tbl_deep_extend(
				"force",
				vim.lsp.protocol.make_client_capabilities(),
				require("cmp_nvim_lsp").default_capabilities(),
				-- File watching is disabled by default for neovim.
				-- See: https://github.com/neovim/neovim/pull/22405
				{ workspace = { didChangeWatchedFiles = { dynamicRegistration = false } } } -- keeping it false because it makes CPU spikes
			),
		})
		-- lspconfig.basedpyright.setup({
		-- 	cmd = { "basedpyright-langserver", "--stdio"},
		--
		-- 	capabilities = vim.tbl_deep_extend(
		-- 		"force",
		-- 		vim.lsp.protocol.make_client_capabilities(),
		-- 		require("cmp_nvim_lsp").default_capabilities(),
		-- 		-- File watching is disabled by default for neovim.
		-- 		-- See: https://github.com/neovim/neovim/pull/22405
		-- 		{ workspace = { didChangeWatchedFiles = { dynamicRegistration = false } } } -- keeping it false because it makes CPU spikes
		-- 	),
		-- })
		-- lua
		lspconfig.lua_ls.setup({
			cmd = { "lua-language-server" },
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						checkThirdParty = false,
						library = {
							vim.fn.expand("$VIMRUNTIME"),
							require("neodev.config").types(),
							"${3rd}/busted/library",
							"${3rd}/luassert/library",
						},
						maxPreload = 5000,
						preloadFileSize = 10000,
					},
					telemetry = { enable = false },
				},
			},
		})
		-- NIX
		-- lspconfig.nil_ls.setup({
		-- 	autostart = true,
		-- 	cmd = { "nil" },
		-- 	settings = {
		-- 		["nil"] = {
		-- 			formatting = {
		-- 				command = { "nixpkgs-fmt" },
		-- 			},
		-- 		},
		-- 	},
		-- })
		lspconfig.nixd.setup{}
		-- BASH
		lspconfig.bashls.setup({
			cmd = { "bash-language-server", "start" },
		})
		-- DOCKER
		lspconfig.docker_compose_language_service.setup({})
		-- YAML
		lspconfig.yamlls.setup({
			settings = {
				redhat = {
					telemetry = {
						enabled = false,
					},
				},
			},
		})
		-- Typescript
		-- lspconfig.type
		require("lsp_signature").setup({
			bind = true, -- This is mandatory, otherwise border config won't get registered.
			handler_opts = {
				border = "rounded",
			},
		})
	end,
}

local LspSaga = NixPlugin("kkharji/lspsaga", {
	config = function()
		require("lspsaga").setup({ lightbulb = { enable = false } })
	end,
})

return {
	lspconfig_toplevel,
	LspSaga,
	Conform,
}
