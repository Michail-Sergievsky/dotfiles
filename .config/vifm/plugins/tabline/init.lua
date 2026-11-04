-- Adapted from Vifm v0.14.4 data/plugins/tabline/init.lua.
-- User11..User16 are defined by colors/tinty.vifm; User1..User4 stay untouched.
local function fmt(info)
    local count = vifm.tabs.getcount({ other = info.other })
    local current = vifm.tabs.getcurrent({ other = info.other })
    local parts = {}
    for index = 1, count do
        local tab = vifm.tabs.get({ index = index, other = info.other })
        local view = tab:getview()
        local name = tab:getname()
        if #name == 0 then
            name = vifm.fnamemodify(view.cwd, ':t')
            if #name == 0 then name = '/' else name = name .. '/' end
        end
        local custom = view.custom
        if custom ~= nil then
            local title = custom.type == 'tree' and 'tree' or custom.title
            name = string.format('[%s] %s', title, name)
        end
        -- Directory/tab names are text, not tabline formatting commands.
        name = string.gsub(name, '%%', '%%%%')
        name = string.gsub(name, '%c', ' ')
        local active = index == current
        local last = index == count
        local start_color = active and 11 or 14
        local end_color
        if active then end_color = last and 13 or 12
        else end_color = last and 16 or 15 end
        local separator = ''
        if not active and not last and index ~= current - 1 then
            separator = ''
            end_color = 14
        end
        parts[#parts + 1] = string.format('%%%d* %d: %s %%%d*%s',
            start_color, index, name, end_color, separator)
    end
    return { format = table.concat(parts) .. '%*' }
end

if not vifm.addhandler({ name = 'fmt', handler = fmt }) then
    vifm.sb.error('Failed to register #%s#fmt', vifm.plugin.name)
end
return {}
