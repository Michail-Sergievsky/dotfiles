-- Autocommands

local api = vim.api

-- ============================================================
-- Autosave
-- ============================================================

-- Save all modified files when Neovim loses focus.
api.nvim_create_autocmd("FocusLost", {
  pattern = "*",
  callback = function()
    vim.cmd("silent! wall")
  end,
  desc = "Save all modified files when Neovim loses focus",
})

-- Save the current file whenever text changes in Normal mode.
api.nvim_create_autocmd("TextChanged", {
  pattern = "*",
  callback = function()
    if vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
      vim.cmd("silent! write")
    end
  end,
  desc = "Autosave normal file buffers after text changes",
})


-- ============================================================
-- Prose files
-- ============================================================

local text_group = api.nvim_create_augroup("TextSettings", {
  clear = true,
})

local function enable_prose_wrapping()
  vim.opt_local.textwidth = 78
  vim.opt_local.formatoptions:append("t")
  vim.b.prose_wrapping = true
end

api.nvim_create_autocmd("FileType", {
  group = text_group,
  pattern = { "markdown", "text" },
  callback = enable_prose_wrapping,
  desc = "Hard-wrap Markdown and text prose at 78 characters",
})

api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = text_group,
  pattern = "*",
  callback = function(args)
    local filename = vim.fn.fnamemodify(args.file, ":t")

    if filename ~= "" and not filename:find(".", 1, true) then
      enable_prose_wrapping()
    end
  end,
  desc = "Hard-wrap extensionless prose files at 78 characters",
})

local function wrap_prose_lines(lines, width)
  local wrapped = {}
  local words = {}

  local function flush_paragraph()
    local line = ""

    for _, word in ipairs(words) do
      local separator = line == "" and "" or " "
      if line ~= "" and vim.fn.strdisplaywidth(line .. separator .. word) > width then
        table.insert(wrapped, line)
        line = word
      else
        line = line .. separator .. word
      end
    end

    if line ~= "" then
      table.insert(wrapped, line)
    end

    words = {}
  end

  for _, source_line in ipairs(lines) do
    if source_line:match("^%s*$") then
      flush_paragraph()
      table.insert(wrapped, "")
    else
      for word in source_line:gmatch("%S+") do
        table.insert(words, word)
      end
    end
  end

  flush_paragraph()
  return wrapped
end

local function format_prose_range(buffer, first_line, last_line)
  vim.schedule(function()
    if not first_line or last_line < first_line or not api.nvim_buf_is_valid(buffer) then
      return
    end

    local window = api.nvim_get_current_win()
    if api.nvim_win_get_buf(window) ~= buffer then
      return
    end

    local view = vim.fn.winsaveview()
    vim.cmd(("keepjumps normal! %dGV%dGgq"):format(first_line, last_line))
    vim.fn.winrestview(view)
  end)
end

-- Terminal and GUI pastes bypass formatoptions.  Reformat the pasted line
-- range after each completed paste, but only in the prose buffers above.
local default_paste = vim.paste

vim.paste = function(lines, phase)
  local buffer = api.nvim_get_current_buf()
  local is_prose = vim.b[buffer].prose_wrapping

  if is_prose and (phase == 1 or phase == -1) then
    vim.b[buffer].prose_paste_start = api.nvim_win_get_cursor(0)[1]
  end

  local result = default_paste(lines, phase)

  if is_prose and (phase == 3 or phase == -1) then
    local first_line = vim.b[buffer].prose_paste_start
    vim.b[buffer].prose_paste_start = nil
    format_prose_range(buffer, first_line, api.nvim_win_get_cursor(0)[1])
  end

  return result
end

-- Wrap characterwise registers before p/P puts them. This leaves existing
-- text on the insertion line untouched, unlike formatting after the put.
local function put_wrapped_text(key)
  if not vim.b.prose_wrapping then
    return key
  end

  local register = vim.v.register
  local contents = vim.fn.getreg(register, 1, true)
  local register_type = vim.fn.getregtype(register)

  if register_type ~= "v" or #contents == 0 then
    return key
  end

  vim.fn.setreg(register, wrap_prose_lines(contents, 78), register_type)
  vim.defer_fn(function()
    vim.fn.setreg(register, contents, register_type)
  end, 100)

  return key
end

vim.keymap.set("n", "p", function()
  return put_wrapped_text("p")
end, { expr = true, desc = "Put wrapped prose text" })

vim.keymap.set("n", "P", function()
  return put_wrapped_text("P")
end, { expr = true, desc = "Put wrapped prose text before cursor" })


-- ============================================================
-- Restore cursor position
-- ============================================================

local cursor_group = api.nvim_create_augroup("RestoreCursor", {
  clear = true,
})

api.nvim_create_autocmd("BufReadPost", {
  group = cursor_group,
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)

    if mark[1] > 0
        and mark[1] <= line_count
        and vim.bo.filetype ~= "gitcommit"
    then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
  desc = "Restore cursor to last known position",
})


-- ============================================================
-- Automatic views
-- ============================================================

local view_group = api.nvim_create_augroup("AutoView", {
  clear = true,
})

local function is_normal_file_buffer()
  return vim.bo.buftype == ""
    and vim.api.nvim_buf_get_name(0) ~= ""
end

api.nvim_create_autocmd("BufWinLeave", {
  group = view_group,
  pattern = "*",
  callback = function()
    if is_normal_file_buffer() then
      vim.cmd("silent! mkview!")
    end
  end,
  desc = "Save view when leaving a normal file buffer",
})

api.nvim_create_autocmd("BufWinEnter", {
  group = view_group,
  pattern = "*",
  callback = function()
    if is_normal_file_buffer() then
      vim.cmd("silent! loadview")
    end
  end,
  desc = "Restore saved view when entering a normal file buffer",
})


-- ============================================================
-- Cursor line only in active window
-- ============================================================

local cursorline_group = api.nvim_create_augroup("ActiveCursorLine", {
  clear = true,
})

api.nvim_create_autocmd("WinEnter", {
  group = cursorline_group,
  pattern = "*",
  callback = function()
    vim.opt_local.cursorline = true
  end,
  desc = "Show cursor line in active window",
})

api.nvim_create_autocmd("WinLeave", {
  group = cursorline_group,
  pattern = "*",
  callback = function()
    vim.opt_local.cursorline = false
  end,
  desc = "Hide cursor line in inactive window",
})

-- ============================================================
-- Quickfix mappings
-- ============================================================

local quickfix_group = api.nvim_create_augroup("QuickfixMappings", {
  clear = true,
})

api.nvim_create_autocmd("FileType", {
  group = quickfix_group,
  pattern = "qf",

  callback = function(event)
    local opts = {
      buffer = event.buf,
      silent = true,
    }

    vim.keymap.set(
      "n",
      "<CR>",
      "<CR>",
      vim.tbl_extend("force", opts, {
        desc = "Open quickfix entry",
      })
    )

    vim.keymap.set(
      "n",
      "K",
      "<Plug>(qf_qf_previous)zz<C-w>w",
      vim.tbl_extend("force", opts, {
        desc = "Previous quickfix item and stay in quickfix window",
      })
    )

    vim.keymap.set(
      "n",
      "J",
      "<Plug>(qf_qf_next)zz<C-w>w",
      vim.tbl_extend("force", opts, {
        desc = "Next quickfix item and stay in quickfix window",
      })
    )
  end,

  desc = "Configure mappings for quickfix windows",
})
