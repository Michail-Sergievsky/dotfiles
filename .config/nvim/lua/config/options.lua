-- General editor options

-- Short alias for Neovim's option interface.
local opt = vim.opt

-- Allow Backspace over indentation, line breaks, and text inserted before Insert mode started.
opt.backspace = { "indent", "eol", "start" }

-- Check whether this Neovim build supports the unnamedplus clipboard feature.
if vim.fn.has("unnamedplus") == 1 then
  -- Use the system clipboard for normal yank, delete, change, and paste operations.
  opt.clipboard = { "unnamed", "unnamedplus" }
-- End the clipboard-support check.
end



-- Show two columns reserved for fold indicators.
opt.foldcolumn = "2"

-- Create folds from explicit {{{ and }}} markers.
opt.foldmethod = "marker"


-- Keep up to 1000 entries in command and search history.
opt.history = 1000

-- Highlight all matches of the current search pattern.
opt.hlsearch = true

-- Ignore case when searching by default.
opt.ignorecase = true

-- Show search matches while the search pattern is being typed.
opt.incsearch = true

-- Make searches case-sensitive when the pattern contains uppercase letters.
opt.smartcase = true

-- Always show the status line when there is more than one window.
opt.laststatus = 2

-- Enable mouse support in all Neovim modes.
opt.mouse = "a"

-- Show absolute line numbers.
opt.number = true

-- Keep at least five screen lines visible above and below the cursor.
opt.scrolloff = 5

-- Keep at least five screen columns visible to the left and right of the cursor.
opt.sidescrolloff = 5

-- Show partially typed Normal-mode commands in the command area.
opt.showcmd = true

-- Briefly highlight the matching bracket when the cursor passes over a bracket.
opt.showmatch = true

-- Show command-line completion matches in a menu.
opt.wildmenu = true

-- Complete command-line matches by longest common part, then list, then cycle through all matches.
opt.wildmode = { "longest", "list", "full" }

-- Remove octal-number recognition from CTRL-A / CTRL-X number operations.
opt.nrformats:remove("octal")

-- Use American English and Russian dictionaries for spell checking.
opt.spelllang = { "en_us", "ru_ru" }


-- Use a visual bell instead of an audible terminal bell.
opt.visualbell = true

-- Reduce update delay for CursorHold events, swap writes, and responsive plugins.
opt.updatetime = 250

-- Automatically write modified buffers when commands require it.
opt.autowriteall = true

-- Do not create backup files before overwriting existing files.
opt.backup = false

-- Do not create swap files for open buffers.
opt.swapfile = false

-- Save undo history to disk so undo survives Neovim restarts.
opt.undofile = true

-- Store persistent undo files under Neovim's state directory.
opt.undodir = vim.fn.stdpath("state") .. "/undo//"

-- Keep up to 10,000 undo changes in memory.
opt.undolevels = 10000

-- Restore up to 10,000 lines of undo history when reloading a buffer.
opt.undoreload = 10000

-- Add the Vimwiki tags file to the list searched by tag commands.
opt.tags:append(vim.fn.expand("~/Vimwiki/tags.wiki"))

-- Define the Russian JCUKEN keyboard mapping for Neovim's built-in input-method support.
opt.keymap = "russian-jcukenwin"

-- Start Insert mode with the normal keyboard layout rather than the Neovim keymap.
opt.iminsert = 0

-- Use the normal keyboard layout for search patterns by default.
opt.imsearch = 0

-- Make Normal-mode commands work by physical key position
-- even when the system keyboard layout is Russian.
-- opt.langmap = "йq,цw,уe,кr,еt,нy,гu,шi,щo,зp,фa,ыs,вd,аf,пg,рh,оj,лk,дl,ж\\;,э',яz,чx,сc,мv,иb,тn,ьm,б\\,,ю.,х[,ъ],ё`,ЙQ,ЦW,УE,КR,ЕT,НY,ГU,ШI,ЩO,ЗP,ФA,ЫS,ВD,АF,ПG,РH,ОJ,ЛK,ДL,Ж:,Э\\\",ЯZ,ЧX,СC,МV,ИB,ТN,ЬM,Б<,Ю>,Х{,Ъ},Ё~,№#"

-- Copy indentation from the previous line when starting a new line.
opt.autoindent = true

-- Preserve the structure of existing indentation when changing indentation.
opt.copyindent = true

-- Insert real TAB characters instead of spaces when Tab is used for indentation.
opt.expandtab = false

-- Make Tab and Backspace respect shiftwidth at the start of a line.
opt.smarttab = true

-- Use four columns for each automatic indentation step.
opt.shiftwidth = 4

-- Round indentation changes to a multiple of shiftwidth.
opt.shiftround = true

-- Make Tab/Backspace behave as if a tab stop is four columns wide while editing.
opt.softtabstop = 4

-- Display literal TAB characters using four-column tab stops.
opt.tabstop = 4

-- Wrap long lines onto additional screen rows.
opt.wrap = true

-- Prefer wrapping long lines at word boundaries.
opt.linebreak = true

-- Do not show invisible whitespace characters by default.
opt.list = false

-- Define how invisible characters are displayed when 'list' is enabled.
opt.listchars = {
  tab = "»-",
  space = "·",
  nbsp = "~",
  trail = "-",
  eol = "$",
  precedes = "<",
  extends = ">",
}

-- Add image extensions to the filename-completion ignore list.
opt.wildignore:append({
  -- Ignore BMP images during command-line filename completion.
  "*.bmp",
  -- Ignore GIF images during command-line filename completion.
  "*.gif",
  -- Ignore ICO images during command-line filename completion.
  "*.ico",
  -- Ignore JPEG images during command-line filename completion.
  "*.jpg",
  -- Ignore PNG images during command-line filename completion.
  "*.png",
-- End of the ignored image-extension list.
})

-- Highlight the screen line containing the cursor.
opt.cursorline = true

-- Highlight the screen column containing the cursor.
opt.cursorcolumn = true

-- Store :mkview files under Neovim's state directory.
opt.viewdir = vim.fn.stdpath("state") .. "/view//"

-- Save folds and current directory in views, but leave cursor restoration
-- to the dedicated RestoreCursor autocmd.
opt.viewoptions = {
  "folds",
  "curdir",
}

-- Enable automatic Insert-mode completion.
opt.autocomplete = true

-- Include LSP omni-completion among automatic completion sources.
opt.complete:append("o")

-- Show the completion menu without inserting a candidate automatically.
opt.completeopt = {
  "menu",
  "menuone",
  "noinsert",
}
