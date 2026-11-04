-- Key mappings

local M = {}

local map = vim.keymap.set
local functions = require("config.functions")

local function insert_code_block(language)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local fence = "```" .. (language or "")

  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, {
    fence,
    "",
    "",
    "",
    "```",
  })

  -- Preserve the practical workflow: put cursor inside the new block.
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
end

-- ============================================================
-- Movements
-- ============================================================

-- Move by displayed screen lines instead of logical lines.
map("n", "j", "gj", {
  silent = true,
  desc = "Move down by screen line",
})

map("n", "k", "gk", {
  silent = true,
  desc = "Move up by screen line",
})

map("n", "0", "g0", {
  silent = true,
  desc = "Move to start of screen line",
})

map("n", "$", "g$", {
  silent = true,
  desc = "Move to end of screen line",
})

map("n", "<Home>", "g<Home>", {
  silent = true,
  desc = "Move to start of screen line",
})

map("n", "<End>", "g<End>", {
  silent = true,
  desc = "Move to end of screen line",
})

map("x", "j", "gj", {
  silent = true,
  desc = "Move down by screen line",
})

map("x", "k", "gk", {
  silent = true,
  desc = "Move up by screen line",
})

-- ============================================================
-- Markdown / Vimwiki code blocks
-- ============================================================

map("n", "<leader>cc", function()
  insert_code_block()
end, {
  desc = "Insert blank code block",
})

map("n", "<leader>cb", function()
  insert_code_block("bash")
end, {
  desc = "Insert Bash code block",
})

map("n", "<leader>cp", function()
  insert_code_block("python")
end, {
  desc = "Insert Python code block",
})

map("n", "<leader>cs", function()
  insert_code_block("sql")
end, {
  desc = "Insert SQL code block",
})

map("n", "<leader>cg", function()
  insert_code_block("git")
end, {
  desc = "Insert Git code block",
})

map("n", "<leader>cv", function()
  insert_code_block("vim")
end, {
  desc = "Insert Vim code block",
})

map("n", "<leader>ct", "<cmd>VimwikiTOC<CR>", {
  desc = "Generate Vimwiki table of contents",
})


-- vimwiki anchor
map("n", "<leader>c]", 'viwc[[#<C-r>"]]<Esc>', {
  desc = "Wrap word as Vimwiki anchor",
})
map("x", "<leader>c]", 'c[[#<C-r>"]]<Esc>', {
  desc = "Wrap selection as Vimwiki anchor",
})
-- ============================================================
-- Text formatting
-- ============================================================

-- Wrap current WORD in bold Markdown markers.
map("n", "<leader>ft", 'ciW**<C-r>"**<Esc>w', {
  desc = "Make WORD bold",
})

-- Wrap the entire current line in bold markers.
map("n", "<leader>fb", "I**<Esc>A**<Esc>", {
  desc = "Make line bold",
})

-- Wrap current WORD in italic Markdown markers.
map("n", "<leader>fi", 'ciW_<C-r>"_<Esc>w', {
  desc = "Make WORD italic",
})

-- Wrap the entire current line in italic markers.
map("n", "<leader>fI", "I_<Esc>A_<Esc>", {
  desc = "Make line italic",
})

-- Wrap current WORD in inline-code backticks.
map("n", "<leader>fc", 'ciW`<C-r>"`<Esc>w', {
  desc = "Make WORD inline code",
})

-- Wrap the entire current line in backticks.
map("n", "<leader>fC", "I`<Esc>A`<Esc>", {
  desc = "Make line inline code",
})


-- Convert Jira {noformat} pairs to Markdown Bash code fences.
map("n", "<leader>fp", functions.convert_noformat, {
  desc = "Convert {noformat} to Bash fences",
})

-- Choose the first spelling suggestion for the word under cursor.
map("n", "<leader>fs", "1z=", {
  desc = "Use first spelling suggestion",
})

-- ============================================================
-- General leader mappings
-- ============================================================

-- Insert current date/time after the cursor.
map("n", "<leader>ds1", function()
  local text = os.date("%Y-%m-%d %H:%M:%S")
  vim.api.nvim_put({ text }, "c", true, true)
end, {
  desc = "Insert date and time",
})

-- Insert current date after the cursor.
map("n", "<leader>ds2", function()
  local text = os.date("%Y-%m-%d")
  vim.api.nvim_put({ text }, "c", true, true)
end, {
  desc = "Insert date",
})

-- Windows / splits
map("n", "<leader>h", "<cmd>split<CR>", {
  desc = "Horizontal split",
})

map("n", "<leader>v", "<cmd>vsplit<CR>", {
  desc = "Vertical split",
})

map("n", "<leader>o", "<cmd>only<CR>", {
  desc = "Close all other windows",
})

map("n", "<leader>x", "<cmd>close<CR>", {
  desc = "Close current window",
})

-- Show buffers and start :buffer command.
map("n", "<leader>l", function()
  vim.cmd("ls")
  vim.api.nvim_feedkeys(":b ", "n", false)
end, {
  desc = "Select buffer",
})

-- Close all folds except the fold containing the cursor,
-- then center the current line.
map("n", "<leader>z", "zMzvzz", {
  desc = "Focus current fold",
})

map("n", "<leader><leader>", "<cmd>b#<CR>", {
  desc = "Previous buffer",
})


-- ============================================================
-- Search / substitute
-- ============================================================

map("n", "<leader>sq", ":%s:::g<Left><Left><Left>", {
  desc = "Substitute in current file",
})

map("n", "<leader>sw", ":vim //jg ***<Left><Left><Left><Left><Left><Left><Left>", {
  desc = "Search recursively with vimgrep",
})

map("n", "<leader>se", ":cfdo %s:::gc<Left><Left><Left><Left>", {
  desc = "Substitute across quickfix files",
})

map("n", "<leader>sr", ":/^\\*\\*\\*\\*$<Left><Left><Left><Left><Left>", {
  desc = "Search for separator line",
})

map("n", "<leader>sy", "<cmd>write !sudo tee % >/dev/null<CR><CR>", {
  desc = "Write current file with sudo",
})

map("n", "<leader>su", ":%s/{noformat}/```/g<CR>", {
  desc = "Replace {noformat} with code fences",
})

map("n", "<leader>si", ":%s/\\*\\([^*]*\\)\\*/# \\1/<CR>", {
  desc = "Convert *text* to Markdown heading",
})

-- ============================================================
-- Git
-- ============================================================

map("n", "<leader>g2", "<cmd>diffget //2<CR>", {
  desc = "Get merge change from target parent [Diffget our]",
})

map("n", "<leader>g3", "<cmd>diffget //3<CR>", {
  desc = "Get merge change from merge parent [Diffget theirs]",
})

-- ============================================================
-- Miscellaneous
-- ============================================================

-- Files containing key mappings outside Neovim.
local config_search_files = {
  vim.fn.expand("~/.config/sway/config"),
  vim.fn.expand("~/.config/vifm/vifmrc"),
  vim.fn.expand("~/.config/tmux/tmux.conf"),
}

-- Add all Neovim Lua configuration files.
vim.list_extend(
  config_search_files,
  vim.fn.glob(
    vim.fn.expand("~/.config/nvim/**/*.lua"),
    false,
    true
  )
)

-- Add Rofi configuration/scripts.
vim.list_extend(
  config_search_files,
  vim.fn.glob(
    vim.fn.expand("~/.config/rofi/**/*.rasi"),
    false,
    true
  )
)

vim.list_extend(
  config_search_files,
  vim.fn.glob(
    vim.fn.expand("~/.config/rofi/**/*.sh"),
    false,
    true
  )
)

local config_mapping_patterns = {
  alt = [[\v(<A-|(^|\s)M-|\$alt\+|Alt\+|Mod1\+)]],
  ctrl = [[\v(<C-|(^|\s)C-|Ctrl\+|Control\+)]],
  shift = [[\v(<S-|(^|\s)S-|Shift\+)]],
}

local function search_config_mappings(modifier)
  local pattern = config_mapping_patterns[modifier]

  if not pattern then
    vim.notify(
      "Unknown mapping modifier: " .. modifier,
      vim.log.levels.ERROR
    )
    return
  end

  local files = {}

  for _, file in ipairs(config_search_files) do
    if vim.fn.filereadable(file) == 1 then
      table.insert(files, vim.fn.fnameescape(file))
    end
  end

  vim.cmd(
    "silent vimgrep /" .. pattern .. "/j " .. table.concat(files, " ")
  )

  vim.cmd("copen")
end

map("n", "<leader>ma", function()
  search_config_mappings("alt")
end, {
  desc = "Search Alt mappings in configs",
})

map("n", "<leader>mc", function()
  search_config_mappings("ctrl")
end, {
  desc = "Search Ctrl mappings in configs",
})

map("n", "<leader>ms", function()
  search_config_mappings("shift")
end, {
  desc = "Search Shift mappings in configs",
})

map("n", "<leader>md", functions.build_pdf, {
  desc = "Build PDF from Markdown",
})

map("n", "<leader>mhc", "<cmd>CtrlMaps<CR>", {
  desc = "Show Ctrl mappings",
})

map("n", "<leader>mha", "<cmd>AltMaps<CR>", {
  desc = "Show Alt mappings",
})

map("n", "<leader>mhs", "<cmd>ShiftMaps<CR>", {
  desc = "Show Shift mappings",
})


-- ============================================================
-- External tools / shell commands
-- ============================================================

-- Open the filename or URL under the cursor with the desktop default app.
map("n", "<leader>a", function()
  local target = vim.fn.expand("<cfile>")

  if target == "" then
    vim.notify("No file or URL under cursor", vim.log.levels.WARN)
    return
  end

  vim.ui.open(target)
end, {
  desc = "Open file or URL under cursor",
})

-- ============================================================
-- Vimwiki tables
-- ============================================================

map("n", "<leader>tn", ":VimwikiTable ", {
  desc = "Create Vimwiki table",
})

map("n", "<leader>tl", "<cmd>VimwikiTableMoveColumnLeft<CR>", {
  desc = "Move Vimwiki table column left",
})

map("n", "<leader>tr", "<cmd>VimwikiTableMoveColumnRight<CR>", {
  desc = "Move Vimwiki table column right",
})

-- ============================================================
-- Tags
-- ============================================================

map("n", "<localleader>tt", function()
  local word = vim.fn.expand("<cword>")
  functions.add_tag(word)
end, {
  desc = "Add tag for word under cursor",
})

map("x", "<localleader>t", function()
  local old_z = vim.fn.getreg("z")
  local old_z_type = vim.fn.getregtype("z")

  vim.cmd('normal! "zy')
  local text = vim.fn.getreg("z")

  vim.fn.setreg("z", old_z, old_z_type)

  functions.add_tag(text)
end, {
  desc = "Add tag for visual selection",
})

-- ============================================================
-- Ctrl mappings
-- ============================================================

-- Delete first blank line above current line.
map("n", "<C-m>", [[m`:silent -g/\m^\s*$/d<CR>``:noh<CR>]], {
  silent = true,
  desc = "Delete first blank line above",
})

-- Delete first blank line below current line.
map("n", "<C-n>", [[m`:silent +g/\m^\s*$/d<CR>``:noh<CR>]], {
  silent = true,
  desc = "Delete first blank line below",
})


-- ============================================================
-- Alt mappings
-- ============================================================

-- Resize splits.
map("n", "<A-n>", "<cmd>vertical resize +3<CR>", {
  silent = true,
  desc = "Increase split width",
})

map("n", "<A-m>", "<cmd>vertical resize -3<CR>", {
  silent = true,
  desc = "Decrease split width",
})

map("n", "<A-p>", "<cmd>resize -3<CR>", {
  silent = true,
  desc = "Decrease split height",
})

map("n", "<A-;>", "<cmd>resize +3<CR>", {
  silent = true,
  desc = "Increase split height",
})

-- Insert blank line above / below without entering Insert mode.
map("n", "<A-o>", "m`O<Esc>``", {
  silent = true,
  desc = "Insert blank line above",
})

map("n", "<A-i>", "m`o<Esc>``", {
  silent = true,
  desc = "Insert blank line below",
})

-- Move current tab left / right.
map("n", "<A-r>", "<cmd>tabmove -1<CR>", {
  silent = true,
  desc = "Move tab left",
})

map("n", "<A-t>", "<cmd>tabmove +1<CR>", {
  silent = true,
  desc = "Move tab right",
})

-- Buffers.
map("n", "<A-f>", "<cmd>bnext<CR>", {
  silent = true,
  desc = "Next buffer",
})

map("n", "<A-g>", "<cmd>bprevious<CR>", {
  silent = true,
  desc = "Previous buffer",
})

-- Select entire buffer.
map("n", "<A-q>", "ggVG", {
  silent = true,
  desc = "Select entire buffer",
})


-- ============================================================
-- Shift mappings
-- ============================================================

map("n", "<S-h>", "gT", {
  desc = "Previous tab",
})

map("n", "<S-l>", "gt", {
  desc = "Next tab",
})


-- ============================================================
-- Disable arrow keys
-- ============================================================

map({ "n", "x", "o" }, "<Up>", "<Nop>", {
  desc = "Disable Up arrow",
})

map({ "n", "x", "o" }, "<Down>", "<Nop>", {
  desc = "Disable Down arrow",
})

map({ "n", "x", "o" }, "<Left>", "<Nop>", {
  desc = "Disable Left arrow",
})

map({ "n", "x", "o" }, "<Right>", "<Nop>", {
  desc = "Disable Right arrow",
})


map("n", "<leader>uf", function()
  local foldopen = vim.opt.foldopen:get()
  local enabled = vim.tbl_contains(foldopen, "search")

  if enabled then
    vim.opt.foldopen:remove("search")
    vim.notify("Search will not open folds")
  else
    vim.opt.foldopen:append("search")
    vim.notify("Search can open folds")
  end
end, {
  desc = "Toggle opening folds during search",
})

map("n", "<leader>us", function()
  vim.wo.spell = not vim.wo.spell

  vim.notify(
    "Spell checking " .. (vim.wo.spell and "ON" or "OFF")
  )
end, {
  desc = "Toggle spell checking",
})

map("n", "<leader>un", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, {
  desc = "Toggle relative line numbers",
})

map("n", "<leader>ui", function()
  vim.wo.list = not vim.wo.list
end, {
  desc = "Toggle invisible characters",
})

map("n", "<leader>uw", functions.toggle_wrap, {
  desc = "Toggle wrapped-line navigation",
})

map("n", "<leader>ue", function()
  vim.opt.fileencodings = {
    "utf-8",
    "cp1251",
  }

  vim.cmd("edit")
end, {
  desc = "Reload file as UTF-8 / CP1251",
})

-- ============================================================
-- Insert mode
-- ============================================================

-- Toggle between the normal and Russian keymap.
map("i", "<C-l>", "<C-^>", {
  desc = "Toggle input language keymap",
})

-- Leave Insert mode.
map("i", ";;", "<Esc>", {
  desc = "Exit Insert mode",
})

-- ============================================================
-- Visual mode
-- ============================================================

-- Wrap selected lines in Jira {noformat} markers.
map("x", "<leader>w", function()
  -- Leave Visual mode so wrap_noformat() can use '< and '> marks.
  vim.cmd("normal! <Esc>")

  functions.wrap_noformat()
end, {
  desc = "Wrap selection in {noformat}",
})

-- ============================================================
-- Escape / indentation
-- ============================================================

-- Press Esc twice to clear search highlighting.
map("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", {
  silent = true,
  desc = "Clear search highlighting",
})


-- ============================================================
-- Remaining general mappings
-- ============================================================

-- Follow Vimwiki backlink.
map("n", "<leader>b", "<Plug>VimwikiGoBackLink", {
  desc = "Go back to previous Vimwiki link",
})

-- Open main Neovim config.
map("n", "<leader>rc", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end, {
  desc = "Edit Neovim config",
})

-- Restart Neovim and reload the whole configuration.
map("n", "<leader>rr", "<cmd>restart<CR>", {
  desc = "Restart Neovim and reload config",
})

-- Open a new tab.
map("n", "<leader>tb", "<cmd>tabnew<CR>", {
  desc = "Open new tab",
})

-- float for diagnostic
map("n", "]d", function()
  vim.diagnostic.jump({
    count = 1,
    float = true,
  })
end, {
  desc = "Next diagnostic",
})

map("n", "[d", function()
  vim.diagnostic.jump({
    count = -1,
    float = true,
  })
end, {
  desc = "Previous diagnostic",
})

-- Toggle language for LTeX+.-
map("n", "<leader>ml", functions.toggle_ltex_language, {
  desc = "Toggle LTeX+ language",
})

-- ============================================================
-- PLUGINS
-- ============================================================
-- Comfort
map("n", "<leader>fm", function()
  require("conform").format({
    async = true,
    lsp_format = "fallback",
  })
end, {
  desc = "Format current buffer",
})
-- Telescope
map("n", "<leader>pf", function()
  require("telescope.builtin").find_files()
end, {
  desc = "Find files",
})

map("n", "<leader>pg", function()
  require("telescope.builtin").live_grep()
end, {
  desc = "Live grep",
})

map("n", "<leader>pb", function()
  require("telescope.builtin").buffers()
end, {
  desc = "Find buffers",
})

map("n", "<leader>ph", function()
  require("telescope.builtin").help_tags()
end, {
  desc = "Search help",
})

-- Neo-tree
map("n", "<leader>dd", "<cmd>Neotree toggle filesystem left<CR>", {
  desc = "Toggle file tree",
})

map("n", "<leader>df", "<cmd>Neotree reveal filesystem left<CR>", {
  desc = "Reveal current file",
})

map("n", "<leader>db", "<cmd>Neotree toggle buffers left<CR>", {
  desc = "Buffer tree",
})

map("n", "<leader>dg", "<cmd>Neotree toggle git_status left<CR>", {
  desc = "Git status tree",
})

-- Neogit
map("n", "<leader>gg", "<cmd>Neogit<CR>", {
  desc = "Open Neogit status",
})

  -- Vimwiki mappings

  map("n", "<leader>wc", "<cmd>Calendar<CR>", {
    desc = "Open calendar",
  })

  map("n", "<leader>wd", "<Plug>VimwikiDeleteFile", {
    desc = "Delete current wiki page",
  })

  map("n", "<leader>wi", "<cmd>Diary<CR>", {
    desc = "Open diary index",
  })

  map("n", "<leader>wn", "<Plug>VimwikiMakeDiaryNote", {
    desc = "Open today's diary note",
  })

  map("n", "<leader>wr", "<Plug>VimwikiRenameFile", {
    desc = "Rename current wiki page",
  })

  map("n", "<leader>ws", "<Plug>VimwikiUISelect", {
    desc = "Select Vimwiki",
  })

  map("n", "<leader>wt", "<Plug>VimwikiMakeTomorrowDiaryNote", {
    desc = "Open tomorrow's diary note",
  })

  map("n", "<leader>ww", "<Plug>VimwikiIndex", {
    desc = "Open Vimwiki index",
  })

  map("n", "<leader>wy", "<Plug>VimwikiMakeYesterdayDiaryNote", {
    desc = "Open yesterday's diary note",
  })

  map("n", "<leader>wa", functions.find_all_incomplete_tasks, {
  desc = "Find incomplete tasks in Vimwiki",
})

map("n", "<leader>wx", functions.find_incomplete_tasks, {
  desc = "Find incomplete tasks in current file",
})

-- gitsigns
function M.gitsigns(bufnr)
  local gitsigns = require("gitsigns")

  local function bufmap(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = bufnr,
      desc = desc,
    })
  end

  bufmap("n", "]c", function()
    if vim.wo.diff then
      vim.cmd.normal({ "]c", bang = true })
    else
      gitsigns.nav_hunk("next")
    end
  end, "Next Git hunk")

  bufmap("n", "[c", function()
    if vim.wo.diff then
      vim.cmd.normal({ "[c", bang = true })
    else
      gitsigns.nav_hunk("prev")
    end
  end, "Previous Git hunk")

  bufmap("n", "<leader>gp", gitsigns.preview_hunk, "Preview Git hunk")
  bufmap("n", "<leader>gs", gitsigns.stage_hunk, "Stage Git hunk")
  bufmap("n", "<leader>gr", gitsigns.reset_hunk, "Reset Git hunk")
  bufmap("n", "<leader>gu", gitsigns.undo_stage_hunk, "Undo staged hunk")

  bufmap("n", "<leader>gb", gitsigns.blame_line, "Blame current line")
  bufmap("n", "<leader>gd", gitsigns.diffthis, "Diff current file")
end

-- Codex
map("n", "<leader>ac", "<cmd>CodexFocus<CR>", {
  desc = "Focus / hide Codex",
})
