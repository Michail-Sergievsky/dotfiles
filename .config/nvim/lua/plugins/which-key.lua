return {
  "folke/which-key.nvim",
  event = "VeryLazy",

  config = function()
    local wk = require("which-key")

    wk.setup({})

    wk.add({
      { "<leader>c", group = "code block" },
      { "<leader>d", group = "neo-tree" },
      { "<leader>f", group = "text format" },
      { "<leader>g", group = "git" },

      { "<leader>m", group = "misc" },
      { "<leader>mh", group = "mapping help" },

      { "<leader>p", group = "picker" },
      { "<leader>s", group = "search / substitute" },
      { "<leader>t", group = "tabs / tables" },
      { "<leader>u", group = "ui / view" },
      { "<leader>w", group = "vimwiki" },
    })
  end,
}
