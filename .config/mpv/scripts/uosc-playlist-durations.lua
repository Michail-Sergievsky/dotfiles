-- Show the current playlist in a uosc menu, with local-file durations probed
-- asynchronously through ffprobe.  Results are cached for this MPV session.

local mp = require("mp")
local utils = require("mp.utils")

local script_name = mp.get_script_name()
-- Use uosc's native Playlist menu so it retains all of its built-in controls.
local menu_type = "playlist"
local max_probes = 4

local durations = {}
local queued = {}
local queue = {}
local active_probes = 0

local function is_url(path)
  return path:find("^[%a][%w+%-%.]*://") ~= nil
end

local function format_duration(seconds)
  if not seconds or seconds <= 0 then
    return "?"
  end

  local total = math.floor(seconds + 0.5)
  local hours = math.floor(total / 3600)
  local minutes = math.floor((total % 3600) / 60)
  local remaining_seconds = total % 60

  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, remaining_seconds)
  end

  return string.format("%d:%02d", minutes, remaining_seconds)
end

local function title_for(item)
  if type(item.title) == "string" and #item.title > 0 then
    return item.title
  end

  if item.filename and not is_url(item.filename) then
    return select(2, utils.split_path(item.filename))
  end

  return item.filename or "Unknown item"
end

local function make_menu()
  local playlist = mp.get_property_native("playlist", {})
  local items = {}
  local selected_index = nil

  for index, item in ipairs(playlist) do
    local duration = nil
    local path = item.filename

    if item.current then
      duration = mp.get_property_number("duration", nil)
      selected_index = index
    elseif path and type(durations[path]) == "number" then
      duration = durations[path]
    end

    local duration_hint
    if duration then
      duration_hint = format_duration(duration)
    elseif path and durations[path] == false then
      duration_hint = "?"
    elseif path and is_url(path) then
      duration_hint = "stream"
    else
      duration_hint = "…"
    end

    items[index] = {
      title = title_for(item),
      hint = string.format("%d  %s", index, duration_hint),
      value = index,
      active = item.current,
    }
  end

  return {
    type = menu_type,
    title = "Playlist",
    footnote = "Paste path or URL to add. Ctrl+Up/Down/PgUp/PgDn/Home/End to reorder.",
    item_actions = {
      { name = "move_up", icon = "arrow_upward", label = "Move up (Ctrl+Up/PgUp/Home)", filter_hidden = true },
      { name = "move_down", icon = "arrow_downward", label = "Move down (Ctrl+Down/PgDn/End)", filter_hidden = true },
      { name = "remove", icon = "delete", label = "Remove (Del)" },
    },
    on_paste = "callback",
    on_move = "callback",
    items = items,
    selected_index = selected_index,
  }
end

local function update_menu()
  mp.commandv("script-message-to", "uosc", "update-menu", utils.format_json(make_menu()))
end

local function start_probes()
  while active_probes < max_probes and #queue > 0 do
    local path = table.remove(queue, 1)
    queued[path] = nil
    active_probes = active_probes + 1

    mp.command_native_async({
      name = "subprocess",
      playback_only = false,
      capture_stdout = true,
      args = {
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        path,
      },
    }, function(success, result)
      active_probes = active_probes - 1

      local duration = success and result and result.status == 0
        and tonumber((result.stdout or ""):match("[%d%.]+")) or nil
      durations[path] = duration and duration > 0 and duration or false

      update_menu()
      start_probes()
    end)
  end
end

local function queue_probe(path)
  if not path or is_url(path) or durations[path] ~= nil or queued[path] then
    return
  end

  queued[path] = true
  table.insert(queue, path)
  start_probes()
end

local function open_menu()
  local playlist = mp.get_property_native("playlist", {})
  for _, item in ipairs(playlist) do
    queue_probe(item.filename)
  end

  mp.commandv("script-binding", "uosc/playlist")
  update_menu()
end

mp.add_key_binding(nil, "uosc-playlist-durations", open_menu)
