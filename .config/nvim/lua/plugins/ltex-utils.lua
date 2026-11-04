return {
	"jhofscheier/ltex-utils.nvim",

	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-telescope/telescope.nvim",
	},

	opts = {
		backend = "ltex_plus",

		dictionary = {
			use_vim_dict = true,
		},
	},
}
