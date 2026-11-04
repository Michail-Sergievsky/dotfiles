return {
	{
		"nvim-mini/mini.snippets",

		dependencies = {
			"rafamadriz/friendly-snippets",
		},

		config = function()
			local snippets = require("mini.snippets")
			local gen_loader = snippets.gen_loader

			snippets.setup({
				snippets = {
					gen_loader.from_lang({
						lang_patterns = {
							bash = {
								"shell/shell.json",
							},
							sh = {
								"shell/shell.json",
							},
						},
					}),

					gen_loader.from_file(
						vim.fn.stdpath("config") .. "/snippets/yaml.ansible.json"
					),
				},
			})
		end,
	},
}
