-- General helper functions

local M = {}

-- ============================================================
-- Tags
-- ============================================================

function M.add_tag(default_tag)
  local tagname = vim.fn.input(
    "Tag name: ",
    default_tag or "",
    "tag"
  )

  local tagfile = vim.fn.expand("%:p")

  local tagaddress = vim.fn.input(
    "Address: ",
    "/\\<" .. (default_tag or "") .. "\\>/"
  )

  if tagname == "" or tagaddress == "" then
    return
  end

  local tags_file = vim.fn.expand("~/tags.global")

  local line = table.concat({
    tagname,
    tagfile,
    tagaddress,
  }, "\t")

  local file, err = io.open(tags_file, "a")

  if not file then
    vim.notify(
      "Cannot open tags file: " .. tostring(err),
      vim.log.levels.ERROR
    )
    return
  end

  file:write(line .. "\n")
  file:close()

  vim.notify("Tag added: " .. tagname)
end

-- ============================================================
-- Wrap
-- ============================================================

function M.toggle_wrap()
  vim.wo.wrap = not vim.wo.wrap

  if vim.wo.wrap then
    vim.wo.linebreak = true
    vim.notify("Wrap ON")
  else
    vim.notify("Wrap OFF")
  end
end

-- ============================================================
-- Jira / Markdown helpers
-- ============================================================

function M.wrap_noformat()
  -- Get the start and end lines of the last visual selection.
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  if start_line == 0 or end_line == 0 then
    vim.notify(
      "No visual selection found",
      vim.log.levels.WARN
    )
    return
  end

  -- Insert closing marker after the selected block first.
  vim.api.nvim_buf_set_lines(
    0,
    end_line,
    end_line,
    false,
    { "{noformat}" }
  )

  -- Insert opening marker before the selected block.
  vim.api.nvim_buf_set_lines(
    0,
    start_line - 1,
    start_line - 1,
    false,
    { "{noformat}" }
  )
end

function M.convert_noformat()
  vim.cmd([[
    let s:_noformat_toggle = ['```', '```bash']
    %s/{noformat}/\=reverse(s:_noformat_toggle)[0]/g
    unlet s:_noformat_toggle
  ]])
end

-- ============================================================
-- PDF
-- ============================================================

function M.build_pdf()
  -- Full path to current file.
  local input = vim.api.nvim_buf_get_name(0)

  if input == "" then
    vim.notify(
      "Cannot build PDF: current buffer has no filename",
      vim.log.levels.ERROR
    )
    return
  end

  -- Save current file first.
  vim.cmd("write")

  -- Directory containing the Markdown document.
  -- Relative resources such as images/foo.png are resolved here.
  local input_dir = vim.fs.dirname(input)

  -- Output PDF next to the source file.
  local output = vim.fn.fnamemodify(input, ":r") .. ".pdf"

  local header = vim.fn.expand(
    "~/.config/pandoc/header.tex"
  )

  vim.notify("Building PDF...")

  local result = vim.system({
    "pandoc",
    input,
    "-o",
    output,

    "--pdf-engine=xelatex",

    "--from",
    "markdown-implicit_figures",

    "-V",
    "mainfont=Liberation Sans",

    "-V",
    "geometry:margin=1.5cm",

    "-V",
    "fontsize=11pt",

    "-V",
    "colorlinks=true",

    "-H",
    header,
  }, {
    text = true,
    cwd = input_dir,
  }):wait()

  if result.code ~= 0 then
    vim.notify(
      "PDF build failed:\n" .. (result.stderr or ""),
      vim.log.levels.ERROR
    )
    return
  end

  vim.notify("PDF created: " .. output)
end

-- ============================================================
-- LTeX+
-- ============================================================

function M.toggle_ltex_language()
  local clients = vim.lsp.get_clients({
    name = "ltex_plus",
    bufnr = 0,
  })

  if #clients == 0 then
    vim.notify(
      "LTeX+ is not attached to this buffer",
      vim.log.levels.WARN
    )
    return
  end

  for _, client in ipairs(clients) do
    client.settings = client.settings or {}
    client.settings.ltex = client.settings.ltex or {}

    local current =
      client.settings.ltex.language or "en-US"

    local new_language

    if current == "en-US" then
      new_language = "ru-RU"
    else
      new_language = "en-US"
    end

    client.settings.ltex.language = new_language

    client:notify(
      "workspace/didChangeConfiguration",
      {
        settings = client.settings,
      }
    )

    vim.notify(
      "LTeX+ language: " .. new_language
    )
  end
end

-- ============================================================
-- Vimwiki
-- ============================================================

function M.find_incomplete_tasks()
  local ok = pcall(
    vim.cmd,
    [[lvimgrep /- \[ \]/ %:p]]
  )

  if ok then
    vim.cmd("lopen")
  else
    vim.notify(
      "No incomplete tasks in current file"
    )
  end
end

function M.find_all_incomplete_tasks()
  local ok = pcall(
    vim.cmd,
    [[VimwikiSearch /- \[ \]/]]
  )

  if ok then
    vim.cmd("lopen")
  else
    vim.notify(
      "No incomplete tasks found"
    )
  end
end

return M
