return {
	"nvim-lualine/lualine.nvim",

	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},

	config = function()
		require("lualine").setup({
			options = {
				icons_enabled = true,

				---- Use the Tinted theme.
				theme = "tinted",

				component_separators = {
					left = "",
					right = "",
				},

				section_separators = {
					left = "",
					right = "",
				},

				globalstatus = false,

				disabled_filetypes = {
					statusline = {
						"neo-tree",
					},
				},
			},

			sections = {
				lualine_a = {
					"mode",
				},

				lualine_b = {
					{
						"branch",
						icon = "",
					},

					{
						"diff",
						symbols = {
							added = "+",
							modified = "~",
							removed = "-",
						},
					},
				},

				lualine_c = {
					{
						"filename",
						path = 1,
						symbols = {
							modified = " ⚡",
							readonly = " ",
							unnamed = "[No Name]",
							newfile = "[New]",
						},
					},
				},

				lualine_x = {
					{
						"diagnostics",
						sources = {
							"nvim_diagnostic",
						},
					},

					"encoding",
					"fileformat",
					"filetype",
				},

				lualine_y = {
					"progress",
				},

				lualine_z = {
					"location",
				},
			},

			inactive_sections = {
				lualine_a = {},
				lualine_b = {},

				lualine_c = {
					{
						"filename",
						path = 1,
					},
				},

				lualine_x = {
					"location",
				},

				lualine_y = {},
				lualine_z = {},
			},

			tabline = {
				lualine_a = {
					{
						"tabs",
						mode = 1,
					},
				},

				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
			    lualine_z = {},
			},

			extensions = {
				"neo-tree",
				"quickfix",
			},
		})
	end,
}
