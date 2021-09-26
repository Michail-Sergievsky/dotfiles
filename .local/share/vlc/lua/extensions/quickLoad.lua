function descriptor()
	return {
		title = "Quick Load Playlist",
		version = "1.2.0",
		shortdesc = "Quick Load Playlist",
		description = "Loads a playlist previously saved by Quick Save Playlist.",
		author = "Daniel Grünwald",
		icon = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
		<svg width="30" height="30" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1"><path stroke="none" fill="#33333f" d="m 15,2 -6,8 4,0 0,10 4,0 0,-10 4,0 -6,-8 z M 3.40625,18.59375 0.59375,21.40625 6.15625,27 l 17.6875,0 5.5625,-5.59375 -2.8125,-2.8125 L 22.1875,23 7.8125,23 3.40625,18.59375 z"/></svg>]],
		capabilities = {"trigger"}
	}
end

local function secureLoad(inString, name) 		-- workaround for lua 5.2 removing 'setfenv' and 'load' in lua 5.1 only accepting functions 
	if setfenv then								-- and, of course, VLC on linux uses 5.2, but on Windows it's 5.1 ...
		vlc.msg.dbg("-- Using 'setfenv'! (_VERSION: " .. _VERSION .. ") --")
		
		local func = load(inString:gmatch(".*"), name)
		return setfenv(func, {})
	else
		return load(inString, name, "t", {})
	end
end

function trigger()
	local dirSep = package.config:sub(1,1)
	local saveFile = vlc.config.userdatadir() .. dirSep .. "quicksave.sav"
	
	vlc.msg.info("Loading playlist from '" .. saveFile .. "' ...")
	
	local file, err = io.open(saveFile, "r")
	if not file then error(err) end
	
	local rawData = file:read("*a")
	local data = (secureLoad("return " .. rawData, "Unserialize"))()

	local pl = {}
	local index = 1
	
	while true do
		local item = data[tostring(index)]
		
		if not item then break end
		
		if item.duration == -1 then item.duration = 0 end
		pl[#pl + 1] = item
		index = index + 1
	end
	
	vlc.playlist.clear()
	vlc.playlist.enqueue(pl)
	
	if data.resume then
		vlc.msg.info("Resuming " .. data.resume .. "...")
	
		for i, v in ipairs(vlc.playlist.get("normal").children) do
			if (v.path == data.resume) then
				vlc.playlist.gotoitem(v.id)
				vlc.playlist.pause()
				break
			end
		end
	end
	
	vlc.msg.info("Playlist loaded from '" .. saveFile .. "'!")
end