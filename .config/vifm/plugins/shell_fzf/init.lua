-- Locally adapted from https://github.com/dawsers/shellfzf.vifm
-- Copyright (c) 2025 dawsers; MIT license, see LICENSE.
-- Always review before execution; handle cancellation and restore the TUI.
local function redraw()
    vifm.run({ cmd = ':', pause = 'never', usetermmux = false })
end

local function pick(restore)
    local filename = vifm.expand('$VIFM/shellfzf_commands.txt')
    local file = io.open(filename, 'r')
    if not file then
        vifm.errordialog('Action palette', 'Cannot read ' .. filename)
        return nil
    end
    file:close()
    local job = io.popen('cat -- ' .. vifm.escape(filename)
        .. ' | fzf --no-multi --layout=reverse --prompt="Action> " 2>/dev/tty', 'r')
    if not job then
        redraw()
        restore()
        return nil
    end
    local line = job:read('*l')
    job:close()
    redraw()
    restore()
    if not line then return nil end
    local run, desc, block = line:match(
        '^%s*run%s*=%s*"(.-)"%s*,%s*desc%s*=%s*"(.-)"%s*,%s*block%s*=%s*(%a+)%s*$')
    if not run or run == '' or (block ~= 'true' and block ~= 'false') then
        vifm.errordialog('Action palette', 'Invalid action entry; nothing executed')
        return nil
    end
    return { run = run, desc = desc, block = block == 'true' }
end

local function shell_fzf()
    -- Redrawing via vifm.run() can clear selection; preserve actual entries,
    -- not gs/gv history, including the case where nothing was selected.
    local view = vifm.currview()
    local cwd = view.cwd
    local selected = {}
    for entry in view:selected() do
        selected[entry.location .. '\0' .. entry.name] = true
    end
    local function restore()
        if view.cwd ~= cwd then return end
        local indexes, index = {}, 0
        for entry in view:entries() do
            index = index + 1
            if selected[entry.location .. '\0' .. entry.name] then
                indexes[#indexes + 1] = index
            end
        end
        view:select({ indexes = indexes })
    end
    local action = pick(restore)
    if not action then return true end
    local expanded = vifm.expand(action.run)
    local reviewed = vifm.input({
        prompt = 'Run (Enter confirms, Esc cancels): ',
        initial = expanded,
        complete = 'file',
    })
    if reviewed == nil or reviewed:match('^%s*$') then return true end
    if action.block then
        vifm.run({ cmd = reviewed, pause = 'always', usetermmux = false })
    else
        vifm.startjob({ cmd = reviewed, visible = true,
            description = action.desc, iomode = '' })
    end
    restore()
    return true
end

if not vifm.keys.add({
    shortcut = ',A',
    modes = { 'normal' },
    description = 'Choose and review a shell action',
    handler = shell_fzf,
}) then
    vifm.sb.error('Failed to register the action palette key')
end
return {}
