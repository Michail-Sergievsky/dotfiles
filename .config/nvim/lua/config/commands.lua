-- Custom user commands

local api = vim.api

api.nvim_create_user_command("DiffOrig", function()
	-- Open a vertical scratch buffer.
	vim.cmd("vertical new")

	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false

	-- Read the original file from disk into the scratch buffer.
	vim.cmd("read ++edit #")

	-- Remove the empty first line created by :new.
	vim.cmd("0delete _")

	-- Enable diff mode in the scratch window.
	vim.cmd("diffthis")

	-- Return to the original buffer.
	vim.cmd("wincmd p")

	-- Enable diff mode there as well.
	vim.cmd("diffthis")
end, {
	desc = "Compare current buffer with file on disk",
})

local mode_groups = {
	{ id = "n", name = "NORMAL" },
	{ id = "i", name = "INSERT" },
	{ id = "x", name = "VISUAL" },
	{ id = "o", name = "OPERATOR-PENDING" },
	{ id = "c", name = "COMMAND-LINE" },
	{ id = "t", name = "TERMINAL" },
}

local modifier_maps = {
	ctrl = {
		command = "CtrlMaps",
		title = "Ctrl mappings",
		match = function(lhs)
			return lhs:match("^<C%-") ~= nil
		end,

		desc = {
			n = {
				["<C-A>"] = "Increment number under/after cursor",
				["<C-B>"] = "Scroll one page backward",
				["<C-D>"] = "Scroll half a page down",
				["<C-E>"] = "Scroll window down one line",
				["<C-F>"] = "Scroll one page forward",
				["<C-G>"] = "Show cursor position and file status",
				["<C-H>"] = "Move cursor left",
				["<C-I>"] = "Jump forward in jumplist (same as Tab)",
				["<C-J>"] = "Move cursor down",
				["<C-K>"] = "Lookup keyword with 'keywordprg'",
				["<C-L>"] = "Redraw screen",
				["<C-M>"] = "Next line / Enter",
				["<C-N>"] = "Move cursor down",
				["<C-O>"] = "Jump backward in jumplist",
				["<C-P>"] = "Move cursor up",
				["<C-R>"] = "Redo",
				["<C-T>"] = "Jump backward in tag stack",
				["<C-U>"] = "Scroll half a page up",
				["<C-V>"] = "Start Visual Block mode",
				["<C-W>"] = "Window command prefix",
				["<C-X>"] = "Decrement number under/after cursor",
				["<C-Y>"] = "Scroll window up one line",
				["<C-Z>"] = "Suspend Neovim",
				["<C-]>"] = "Jump to tag under cursor",
				["<C-^>"] = "Switch to alternate buffer",
			},

			i = {
				["<C-A>"] = "Insert previously inserted text",
				["<C-C>"] = "Leave Insert mode",
				["<C-D>"] = "Decrease indent",
				["<C-E>"] = "Insert character from line below",
				["<C-H>"] = "Delete character before cursor",
				["<C-I>"] = "Insert Tab",
				["<C-J>"] = "Insert line break",
				["<C-K>"] = "Enter digraph",
				["<C-M>"] = "Insert line break / Enter",
				["<C-N>"] = "Next completion item",
				["<C-O>"] = "Execute one Normal-mode command",
				["<C-P>"] = "Previous completion item",
				["<C-R>"] = "Insert register contents",
				["<C-T>"] = "Increase indent",
				["<C-U>"] = "Delete to start of inserted text",
				["<C-V>"] = "Insert next character literally",
				["<C-W>"] = "Delete previous word",
				["<C-X>"] = "Insert completion prefix",
				["<C-Y>"] = "Insert character from line above",
				["<C-]>"] = "Trigger abbreviation expansion",
				["<C-^>"] = "Toggle active language keymap",
			},

			x = {
				["<C-A>"] = "Increment numbers in selection",
				["<C-B>"] = "Scroll one page backward",
				["<C-C>"] = "Leave Visual mode",
				["<C-D>"] = "Scroll half a page down",
				["<C-E>"] = "Scroll window down one line",
				["<C-F>"] = "Scroll one page forward",
				["<C-G>"] = "Switch Visual / Select mode",
				["<C-H>"] = "Move cursor left",
				["<C-I>"] = "Jump forward in jumplist",
				["<C-J>"] = "Move cursor down",
				["<C-M>"] = "Move to next line",
				["<C-N>"] = "Move cursor down",
				["<C-O>"] = "Jump to other end of selection",
				["<C-P>"] = "Move cursor up",
				["<C-U>"] = "Scroll half a page up",
				["<C-V>"] = "Visual Block mode",
				["<C-W>"] = "Window command prefix",
				["<C-X>"] = "Decrement numbers in selection",
				["<C-Y>"] = "Scroll window up one line",
				["<C-]>"] = "Jump to tag",
			},

			o = {
				["<C-B>"] = "Page backward motion",
				["<C-D>"] = "Half-page down motion",
				["<C-F>"] = "Page forward motion",
				["<C-H>"] = "Move left",
				["<C-I>"] = "Jump forward in jumplist",
				["<C-J>"] = "Move down",
				["<C-M>"] = "Move to next line",
				["<C-N>"] = "Move down",
				["<C-O>"] = "Jump backward in jumplist",
				["<C-P>"] = "Move up",
				["<C-U>"] = "Half-page up motion",
				["<C-]>"] = "Tag motion",
			},

			c = {
				["<C-A>"] = "Move to start of command line",
				["<C-B>"] = "Move cursor left",
				["<C-C>"] = "Cancel command line",
				["<C-D>"] = "List completion matches",
				["<C-E>"] = "Move to end of command line",
				["<C-F>"] = "Open command-line window",
				["<C-H>"] = "Delete previous character",
				["<C-I>"] = "Complete item / Tab",
				["<C-J>"] = "Accept command line",
				["<C-K>"] = "Enter digraph",
				["<C-M>"] = "Accept command line / Enter",
				["<C-N>"] = "Next history/completion item",
				["<C-P>"] = "Previous history/completion item",
				["<C-R>"] = "Insert register contents",
				["<C-U>"] = "Delete before cursor",
				["<C-V>"] = "Insert next character literally",
				["<C-W>"] = "Delete previous word",
				["<C-Y>"] = "Accept current completion",
			},

			t = {
				["<C-\\><C-N>"] = "Leave Terminal-job mode",
				["<C-\\><C-O>"] = "Execute one Normal command",
			},
		},
	},

	alt = {
		command = "AltMaps",
		title = "Alt mappings",
		match = function(lhs)
			return lhs:match("^<A%-") ~= nil or lhs:match("^<M%-") ~= nil
		end,

		desc = {
			n = {
				["<M-Left>"] = "Alt-Left",
				["<M-Right>"] = "Alt-Right",
				["<M-Up>"] = "Alt-Up",
				["<M-Down>"] = "Alt-Down",
			},
			i = {},
			x = {},
			o = {},
			c = {},
			t = {},
		},
	},

	shift = {
		command = "ShiftMaps",
		title = "Shift mappings",
		match = function(lhs)
			return lhs:match("^<S%-") ~= nil or lhs:match("^%u$") ~= nil
		end,

		desc = {
			n = {
				["G"] = "End of file",
				["H"] = "Top visible screen line",
				["L"] = "Bottom visible screen line",
				["M"] = "Middle visible screen line",
				["N"] = "Repeat search in opposite direction",
				["O"] = "Open line above",
				["P"] = "Put before cursor",
				["R"] = "Replace mode",
				["U"] = "Undo changes on current line",
				["V"] = "Linewise Visual mode",
				["Y"] = "Yank to end of line",
				["<S-Tab>"] = "Shift-Tab",
			},
			i = {},
			x = {},
			o = {},
			c = {},
			t = {},
		},
	},
}

local function collect_mode_maps(mode)
	local result = {}

	for _, mapping in ipairs(api.nvim_get_keymap(mode)) do
		result[mapping.lhs] = mapping
	end

	for _, mapping in ipairs(api.nvim_buf_get_keymap(0, mode)) do
		result[mapping.lhs] = mapping
	end

	return result
end

local function show_modifier_maps(spec)
	local output = {}

	for _, mode in ipairs(mode_groups) do
		local runtime = collect_mode_maps(mode.id)
		local builtin = spec.desc[mode.id] or {}
		local keys = {}

		for lhs in pairs(builtin) do
			keys[lhs] = true
		end

		for lhs in pairs(runtime) do
			if spec.match(lhs) then
				keys[lhs] = true
			end
		end

		local sorted = vim.tbl_keys(keys)

		table.sort(sorted, function(a, b)
			return a:lower() < b:lower()
		end)

		table.insert(output, "")
		table.insert(output, "=== " .. mode.name .. " ===")
		table.insert(output, "")

		for _, lhs in ipairs(sorted) do
			local mapping = runtime[lhs]
			local desc

			if mapping and mapping.desc and mapping.desc ~= "" then
				desc = mapping.desc
			else
				desc = builtin[lhs] or "(no description)"
			end

			table.insert(output, string.format("%-16s %s", lhs, desc))
		end
	end

	vim.cmd("new")

	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	vim.bo.filetype = "keymaps-help"

	api.nvim_buf_set_lines(0, 0, -1, false, output)

	vim.bo.modifiable = false

	vim.keymap.set("n", "q", "<cmd>close<CR>", {
		buffer = true,
		silent = true,
		desc = "Close keymap help",
	})

	vim.cmd("normal! gg")
end

for _, spec in pairs(modifier_maps) do
	api.nvim_create_user_command(spec.command, function()
		show_modifier_maps(spec)
	end, {
		desc = "Show " .. spec.title .. " by mode",
	})
end
