-- Custom highlight overrides

local api = vim.api

local function adjust_color(bg, amount)
  local r = bit.rshift(bg, 16) % 256
  local g = bit.rshift(bg, 8) % 256
  local b = bg % 256

  local brightness = r + g + b

  local function adjust(value)
    if brightness < 384 then
      return math.min(255, value + amount)
    end

    return math.max(0, value - amount)
  end

  return bit.lshift(adjust(r), 16)
    + bit.lshift(adjust(g), 8)
    + adjust(b)
end

local function apply_custom_highlights()
  local normal = api.nvim_get_hl(0, {
    name = "Normal",
    link = false,
  })

  if not normal.bg then
    return
  end

  -- Cursor crosshair:
  -- make it clearly visible, but keep it derived from the theme.
  local cursor_bg = adjust_color(normal.bg, 18)

  api.nvim_set_hl(0, "CursorLine", {
    bg = cursor_bg,
  })

  api.nvim_set_hl(0, "CursorColumn", {
    link = "CursorLine",
  })

  -- Invisible characters:
  -- use a subtler contrast than the cursor crosshair.
  local whitespace_fg = adjust_color(normal.bg, 40)

  api.nvim_set_hl(0, "Whitespace", {
    fg = whitespace_fg,
  })

  -- Search highlighting.
  api.nvim_set_hl(0, "Search", {
    ctermbg = 3,
    ctermfg = 0,
  })
end

apply_custom_highlights()

api.nvim_create_autocmd("ColorScheme", {
  callback = apply_custom_highlights,
  desc = "Reapply custom theme-aware highlights",
})
