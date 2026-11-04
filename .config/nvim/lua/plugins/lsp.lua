return {
	"neovim/nvim-lspconfig",

	config = function()
		-- Configure YAML language server.
		vim.lsp.config("yamlls", {
			settings = {
				yaml = {
					schemas = {
						["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = {
							".gitlab-ci.yml",
							".gitlab-ci.yaml",
						},
					},
				},
			},
		})

		-- Configure LTeX+ grammar and spell checker.
		vim.lsp.config("ltex_plus", {
			filetypes = {
				"bib",
				"context",
				"gitcommit",
				"html",
				"mail",
				"markdown",
				"org",
				"pandoc",
				"plaintex",
				"quarto",
				"rmd",
				"rst",
				"tex",
				"text",
				"typst",
				"xhtml",

				-- Code files: check comments/docstrings.
				"python",
				"lua",
				"sh",
				"bash",
				"javascript",
				"typescript",
			},

			settings = {
				ltex = {
					language = "en-US",

					enabled = {
						"bibtex",
						"context",
						"html",
						"latex",
						"markdown",
						"mdx",
						"typst",
						"asciidoc",
						"neorg",
						"org",
						"quarto",
						"restructuredtext",
						"rsweave",

						-- Check comments/docstrings in code.
						"python",
						"lua",
						"shellscript",
						"javascript",
						"typescript",
					},
				},
			},
		})

		-- Enable language servers.
		vim.lsp.enable({
			"yamlls",
			"ansiblels",
			"bashls",
			"pyright",
			"ruff",
			"lua_ls",
			"marksman",
			"html",
			"cssls",
			"ts_ls",
			"dockerls",
			"sqls",
			"ltex_plus",
		})

		local group = vim.api.nvim_create_augroup("LspRuff", {
			clear = true,
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = group,

			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)

				if client and client.name == "ruff" then
					-- Let Pyright provide Python hover documentation.
					client.server_capabilities.hoverProvider = false
				end
			end,

			desc = "Disable Ruff hover in favor of Pyright",
		})

		local ltex_group = vim.api.nvim_create_augroup("LtexUtils", {
			clear = true,
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = ltex_group,

			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)

				if client and client.name == "ltex_plus" then
					vim.schedule(function()
						require("ltex-utils").on_attach(event.buf)

						-- ltex-utils normally writes a *_ltex.json file alongside every
						-- Markdown/TeX buffer on BufUnload.  Keep LTeX diagnostics and
						-- code actions, but do not add plugin state to project folders.
						vim.api.nvim_clear_autocmds({
							group = "LTeXUtils",
							event = "BufUnload",
						})
					end)
				end
			end,

			desc = "Attach ltex-utils to LTeX+",
		})
	end,
}
