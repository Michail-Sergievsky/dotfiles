-- cycle-profiles.lua
local profiles = {"anime_cut", "Default"}
local current_profile = 1

function cycle_profiles()
    current_profile = current_profile + 1
    if current_profile > #profiles then
        current_profile = 1
    end
    mp.commandv("apply-profile", profiles[current_profile])
    mp.osd_message("Profile: " .. profiles[current_profile])
end

mp.add_key_binding("F1", "cycle-profiles", cycle_profiles)
