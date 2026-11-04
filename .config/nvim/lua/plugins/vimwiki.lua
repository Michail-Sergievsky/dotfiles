return {
	"vimwiki/vimwiki",

	init = function()
		-- Vimwiki must see these globals before the plugin loads.

		vim.g.vimwiki_folding = "syntax"
		vim.g.vimwiki_global_ext = 0
		vim.g.vimwiki_hl_headers = 1
		vim.g.vimwiki_conceal_pre = 1
		vim.g.vimwiki_url_maxsave = 0

		vim.g.vimwiki_ext2syntax = {
			[".md"] = "markdown",
			[".markdown"] = "markdown",
			[".mdown"] = "markdown",
		}

		vim.g.vimwiki_nested_syntaxes = {
			python = "python",
			bash = "bash",
			sql = "sql",
			mysql = "mysql",
			git = "git",
			gitcommit = "gitcommit",
			vim = "vim",
			viminfo = "viminfo",
			c = "c",
			["c++"] = "cpp",
			conf = "conf",
			config = "config",
			cfg = "cfg",
			cmake = "cmake",
			diff = "diff",
			zsh = "zsh",
			xdefaults = "xdefaults",
		}

		vim.g.vimwiki_root = "~/Vimwiki"

		vim.g.vimwiki_list = {
			{
				path = "~/Vimwiki/linux2",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/work",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/notes",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/lists",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/links",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/soft",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/hardware",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/selfimprove",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
			{
				path = "~/Vimwiki/life",
				syntax = "markdown",
				ext = ".md",
				auto_toc = 1,
			},
		}
	end,

	config = function()
		local map = vim.keymap.set

		-- ---------------------------------------------------------
		-- Commands
		-- ---------------------------------------------------------

		vim.api.nvim_create_user_command("Diary", function()
			vim.cmd("VimwikiDiaryIndex")
			vim.cmd("VimwikiDiaryGenerateLinks")
		end, {
			desc = "Open Vimwiki diary index and regenerate diary links",
		})
	end,
}
