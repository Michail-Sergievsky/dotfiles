# Reviewed shell action palette

Local adaptation of https://github.com/dawsers/shellfzf.vifm (MIT).
Tested with Vifm 0.14.4 using its native Lua key API.

Normal-mode shortcut: `,A` (comma then Shift+A). Existing `,a` archives files;
all `f...` search shortcuts remain unchanged. No shellfzf command is registered.

Actions are read from `$VIFM/shellfzf_commands.txt`, one entry per line:

    run = "shell command", desc = "searchable description", block = false

Choose an action with fzf, then review/edit its fully expanded command.
Only a second Enter executes it. Escape cancels either step; blank review
input is also cancelled. Commands run as the current user, not as root.
This is a command launcher, not a sandbox: an edited or newly added command
can change files or launch applications. Review it accordingly.

Differences from upstream: mandatory review; nil/empty cancellation handling;
quoted command-list path; explicit pipe close; TUI redraw before review;
selection preserved by entry identity rather than recalling selection history;
native Lua key binding instead of the command interface that failed isolated
tests in this installation. Blocking commands pause for Enter after output.

Initial actions: Neovim in Kitty, compare current files from both panes,
Kitty in current directory, stat metadata, and default desktop applications.
For comparison, position each pane on the intended file first. With no explicit
selection, file macros use the current file. Default desktop applications may
edit files; there is no global read-only enforcement.

To remove the feature reversibly, move this plugin directory outside
`$VIFM/plugins/` and restart Vifm. Preserve the action list if desired.
The existing vifmrc, tabline plugin, colors and search mappings are unchanged.
