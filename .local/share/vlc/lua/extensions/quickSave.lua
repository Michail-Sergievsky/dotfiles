function descriptor()
	return {
		title = "Quick Save Playlist",
		version = "1.2.0",
		shortdesc = "Quick Save Playlist",
		description = "Saves a playlist that can later be loaded with Quick Load Playlist",
		author = "Daniel Grünwald",
		icon = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
		<svg width="30" height="30" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1"><path stroke="none" fill="#33333f" d="m 13,3 0,10 -4,0 6,8 6,-8 -4,0 0,-10 -4,0 z M 3.40625,18.59375 0.59375,21.40625 6.15625,27 l 17.6875,0 5.5625,-5.59375 -2.8125,-2.8125 L 22.1875,23 7.8125,23 3.40625,18.59375 z"/></svg>]],
		capabilities = {"trigger"}
	}
end

local function serialize(inTable)
	local reserved = {
		["and"]    = true, ["break"]  = true, ["do"]   = true, ["else"]     = true, ["elseif"] = true,
		["end"]    = true, ["false"]  = true, ["for"]  = true, ["function"] = true, ["if"]     = true,
		["in"]     = true, ["local"]  = true, ["nil"]  = true, ["not"]      = true, ["or"]     = true,
		["repeat"] = true, ["return"] = true, ["then"] = true, ["true"]     = true, ["until"]  = true, ["while"] = true
	}

	local visited = {}
	visited[inTable] = true

	local function validKey(k)
		local kType = type(k)
		local allowed = {string = true, number = true, boolean = true}		-- could also include tables, but doesn't make much sense.
		if not allowed[kType] then error("Cannot serialize table with keys of type " .. kType) end

		if kType == "string" then
			if k:match("^%d") or k:match("[^%w_]") or reserved[k] then return "[" .. string.format("%q", k) .. "]"
			else return k end
		else
			return "[" .. tostring(k):gsub(",", ".") .."]"
		end
	end

	local function tabs(l) return ("\t"):rep(l) end
	local function comma(t, k) if (next(t or {}, k)) then return ", " else return "" end end

	local result = "{" .. "\n"

	local level = 1
	local _key = {}
	local _table = {}
	_key[1] = nil
	_table[1] = inTable
	
	local value, key, vType, t
	
	while level > 0 do
		_key[level], value = next(_table[level], _key[level])
		key = _key[level]
		t = _table[level]

		vType = type(value)

		if key == nil then
			level = level - 1
			result = result .. tabs(level) .. "}" .. comma(_table[level], _key[level]) .. "\n"
		else
			if vType == "string" then
				result = result .. tabs(level) .. validKey(key) .. " = " .. string.format("%q", value) .. comma(t, key) .. "\n"
			elseif vType == "number" or vType == "boolean" or vType == "nil" then
				result = result .. tabs(level) .. validKey(key) .. " = " .. tostring(value):gsub(",", ".") .. comma(t, key) .. "\n"
			elseif vType == "table" then
				if visited[value] then error("Cannot serialize table with circular references.") end
				visited[value] = true

				result = result .. tabs(level) .. validKey(key) .. " = {" .. "\n"

				level = level + 1
				_table[level] = value
			else
				-- currently discards all unserializable data silently (namely the keys "item" which are of type "userdata" and not needed anyway)
			end
		end
	end

	return result
end

function trigger()
	local dirSep = package.config:sub(1,1)
	local saveFile = vlc.config.userdatadir() .. dirSep .. "quicksave.sav"
	
	vlc.msg.info("Saving playlist to '" .. saveFile .. "' ...")
	
	local file, err = io.open(saveFile, "w+")
	if not file then error(err) end
	
	local current = vlc.playlist.current()
	local plRaw, pl = vlc.playlist.get("normal").children, { resume = false }
	
	if #plRaw < 1 then
		vlc.msg.info("Nothing to save...")
		return
	end
	
	for i, v in ipairs(plRaw) do
		pl[tostring(i)] = v 		-- converting numerical to string keys to preserve the order
		if v.id == current then pl.resume = v.path end
	end
	
	local sTable = serialize(pl)
	
	local success, err = file:write(sTable)
	if not success then error(err) end
	
	file:close()
	
	vlc.msg.info("Playlist saved as '" .. saveFile .. "'!")
end