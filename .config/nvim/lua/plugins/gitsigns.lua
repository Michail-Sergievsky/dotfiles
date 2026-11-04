return {
  "lewis6991/gitsigns.nvim",

  config = function()
    require("gitsigns").setup({
      on_attach = function(bufnr)
        require("config.keymaps").gitsigns(bufnr)
      end,
    })
  end,
}
