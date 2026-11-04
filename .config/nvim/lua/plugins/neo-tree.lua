return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",

  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },

  config = function()
    require("neo-tree").setup({
      close_if_last_window = false,

      filesystem = {
        follow_current_file = {
          enabled = true,
        },

        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },

      window = {
        width = 35,

        mappings = {
          ["l"] = "open",
        },
      },
    })
  end,
}
