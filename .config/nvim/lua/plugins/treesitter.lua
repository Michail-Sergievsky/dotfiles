return {
  "nvim-treesitter/nvim-treesitter",

  -- Use the modern main branch API.
  branch = "main",

  -- Load Treesitter immediately so parsing/highlighting is available
  -- whenever a supported buffer is opened.
  lazy = false,

  -- Update installed parsers whenever the plugin is updated.
  build = ":TSUpdate",

  config = function()
    local ts = require("nvim-treesitter")

    -- Install parsers used by the filetypes in this config.
    --
    -- Parser names do not always match Neovim filetype names:
    --   sh   -> uses the bash parser
    --   help -> uses the vimdoc parser
    --
    -- markdown_inline is used together with markdown for inline
    -- Markdown constructs.
    ts.install({
      "bash",
      "lua",
      "vim",
      "vimdoc",
      "python",
      "yaml",
      "json",
      "dockerfile",
      "markdown",
      "markdown_inline",
    })

    -- Start Treesitter parsing automatically for supported filetypes.
    --
    -- This is the modern main-branch approach and replaces the older
    -- nvim-treesitter.configs setup style.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "bash",
        "sh",
        "lua",
        "vim",
        "help",
        "python",
        "yaml",
        "json",
        "dockerfile",
        "markdown",
      },

      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
