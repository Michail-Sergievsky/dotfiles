# Multi-file finder

Normal-mode `fM` (f, then Shift+m) searches recursively below the current
pane's directory. Includes hidden files, excludes .git, and otherwise respects
fd ignore rules. It does not restrict searching to an existing selection.

Tab / Shift-Tab mark results. Enter collects marked files (or the highlighted
file if none are marked) in a custom view named `fzf collection`. No files are
opened, copied, moved, or deleted automatically. Results are not automatically
selected for bulk operations; select the desired entries in Vifm afterward.

Esc cancels, retaining the original view, selection, cursor and preview setting.
Use `:regular` to leave the collection. Files in a custom view are real original
files, not copies: subsequent editing/copying/moving/deleting acts on originals.

Uses Vifm 0.14's Lua API, system fd/fzf and NUL-delimited paths, including names
containing spaces, quotes, percent signs and newlines. Global fzf option strings
are deliberately not applied. Existing fz/ff commands and vifmrc are unchanged.
