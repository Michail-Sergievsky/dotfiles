vim.g.mapleader = " "
vim.g.maplocalleader = ","

require("config.options")
require("config.langmap").setup()
require("config.filetype")
require("config.autocmds")
require("config.commands")

require("config.lazy")

require("config.highlights")
require("config.keymaps")
