-- Gather fzf results into a custom view without executing file actions.
local function collect()
    for _, tool in ipairs({ '/usr/bin/fd', '/usr/bin/fzf' }) do
        if not vifm.executable(tool) then
            vifm.errordialog('Multi-file finder', 'Missing executable: ' .. tool)
            return true
        end
    end

    local view = vifm.currview()
    local cwd, cursor = view.cwd, view.cursor.pos
    local selected = {}
    for entry in view:selected() do
        selected[entry.location .. '\0' .. entry.name] = true
    end
    local function restore()
        if view.cwd ~= cwd then return end
        local all, indexes = {}, {}
        for entry in view:entries() do
            local index = #all + 1
            all[index] = index
            if selected[entry.location .. '\0' .. entry.name] then
                indexes[#indexes + 1] = index
            end
        end
        view:unselect({ indexes = all })
        view:select({ indexes = indexes })
        view.cursor.pos = cursor
    end

    -- No user-supplied command text. NUL delimiters preserve all filename bytes
    -- except NUL, which Unix filenames cannot contain. Ignore global fzf options
    -- so unrelated bindings/expect output can't alter this protocol.
    local command = 'cd -- ' .. vifm.escape(cwd)
        .. ' && (/usr/bin/fd --type f --hidden --exclude .git --absolute-path --print0 .'
        .. ' | /usr/bin/env -u FZF_DEFAULT_OPTS -u FZF_DEFAULT_OPTS_FILE'
        .. ' /usr/bin/fzf --read0 --print0 --multi --layout=reverse'
        .. ' --bind=tab:toggle+down,btab:toggle+up'
        .. ' --prompt="Files> "'
        .. ' --header="Tab: mark | Shift-Tab: mark up | Enter: collect | Esc: cancel"'
        .. ' 2>/dev/tty)'
    local job = io.popen(command, 'r')
    if not job then
        vifm.errordialog('Multi-file finder', 'Could not start the picker')
        return true
    end
    local output = job:read('*a')
    local ok, _, code = job:close()
    vifm.run({ cmd = ':', pause = 'never', usetermmux = false })
    restore()
    if not ok then
        if code ~= 1 and code ~= 130 then
            vifm.errordialog('Multi-file finder', 'Picker failed; view unchanged')
        end
        return true
    end
    if not output or output == '' then return true end
    if output:sub(-1) ~= '\0' then
        vifm.errordialog('Multi-file finder', 'Invalid picker output; view unchanged')
        return true
    end
    local paths = {}
    for path in output:gmatch('([^\0]+)\0') do
        if path:sub(1, 1) ~= '/' then
            vifm.errordialog('Multi-file finder', 'Expected absolute paths; view unchanged')
            return true
        end
        paths[#paths + 1] = path
    end
    if #paths > 0 then
        view:loadcustom({ title = 'fzf collection', paths = paths })
    end
    return true
end

if not vifm.keys.add({
    shortcut = 'fM', modes = { 'normal' },
    description = 'Gather files with fzf into a custom view', handler = collect,
}) then
    vifm.sb.error('Failed to register the multi-file finder key')
end
return {}
