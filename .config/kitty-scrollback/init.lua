vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.laststatus = 0
vim.opt.showmode = false
vim.opt.ruler = false
vim.opt.signcolumn = "no"
vim.opt.clipboard = "unnamedplus"

vim.keymap.set("n", "q", "<cmd>qa!<CR>", { silent = true })

vim.keymap.set("v", "y", '"+y<cmd>qa!<CR>', { silent = true })

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("normal! G")
  end,
})
