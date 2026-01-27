-- phonograph/phonograph_core/src/player.lua
-- Player interactions
-- depends: functions, settings
--[[
    Phonograph: Play music from albums
    Copyright (C) 2024  1F616EMO

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

local logger = phonograph.internal.logger:sublogger("player")
local PS = core.pos_to_string

local function vector_distance(pos1, pos2)
    local diff = vector.subtract(pos1, pos2)
    return math.sqrt(diff.x ^ 2 + diff.y ^ 2 + diff.z ^ 2)
end

-- Distances from the controller for a phonograph sound to be heared
phonograph.START_HEARING_DISTANCE = 15
phonograph.STOP_HEARING_DISTANCE = 32

-- phonograph.players[name][controller_pos_hash] =
--    { curr_song = <string>, speakers = { <speaker_pos_hash> = <handle> } }
phonograph.players = {}

local function fade_controller_for_player(ptable, controller_pos_hash)
    for _, handle in pairs(ptable[controller_pos_hash].speakers) do
        core.sound_fade(handle, 0.5, 0)
    end
end

local function play_song_for_player(pname, controller_pos, controller_table, volume, song, connected_speakers)
    for _, speaker_data in ipairs(connected_speakers) do
        local speaker_pos = speaker_data[1]
        local speaker_pos_hash = core.hash_node_position(speaker_pos)
        local speaker_sound_channel = speaker_data[2]
        local speaker_sound_gain = speaker_data[3]
        if not speaker_sound_gain then
            speaker_sound_gain = 100
        end

        local spec = speaker_sound_channel >= 0
            and song.multichannel_specs and song.multichannel_specs[speaker_sound_channel + 1] or song.spec
        if spec then
            local max_hear_distance = vector_distance(controller_pos, speaker_pos) + phonograph.STOP_HEARING_DISTANCE
            controller_table.speakers[speaker_pos_hash] = core.sound_play(spec, {
                pos = speaker_pos,
                loop = true,
                to_player = pname,
                max_hear_distance = max_hear_distance or 32,
                gain = speaker_sound_gain * volume / 10000
            })
        end
    end
end

local function process_one_phonograph(controller_pos, controller_pos_hash, player, pname, ppos, ptable)
    local controller_meta = core.get_meta(controller_pos)
    local meta_curr_song = controller_meta:get_string("curr_song")
    local volume = controller_meta:get_int("sound_volume")
    if volume == 0 then
        volume = 100
        phonograph.set_volume(controller_meta, 100)
    end

    local connected_speakers = phonograph.controller_get_connected_speakers(controller_pos)
    if #connected_speakers == 0 then return end

    if meta_curr_song == "" then
        if ptable[controller_pos_hash] then
            logger:action("Phonograph %s not playing anything, fading audio for %s",
                PS(controller_pos), pname)
            fade_controller_for_player(ptable, controller_pos_hash)
            ptable[controller_pos_hash] = nil
        end
        return
    end

    local song = phonograph.registered_songs[meta_curr_song]

    local channels_to_send_keys = {}
    for _, speaker_data in ipairs(connected_speakers) do
        local channel = speaker_data[2]
        if channel < 0 or (song.multichannel_specs and song.multichannel_specs[channel + 1]) then
            channels_to_send_keys[speaker_data[2]] = true
        else
            channels_to_send_keys[-1] = true
        end
    end
    local channels_to_send = {}
    for k in pairs(channels_to_send_keys) do
        channels_to_send[#channels_to_send + 1] = k
    end

    if ptable[controller_pos_hash] and meta_curr_song ~= ptable[controller_pos_hash].curr_song then
        fade_controller_for_player(ptable, controller_pos_hash)
        if not song then
            logger:action("Phonograph at %s is playing %s but it is not avaliable, " ..
                "fading audio for %s and stopping phonograph.",
                PS(controller_pos), meta_curr_song, pname)
            ptable[controller_pos_hash] = nil
            phonograph.set_song(controller_meta, "")
        elseif phonograph.send_song(player, meta_curr_song, channels_to_send) then
            logger:action("Phonograph at %s is playing %s at volume %s%%, changing the audio of %s",
                PS(controller_pos), meta_curr_song, volume, pname)
            ptable[controller_pos_hash].curr_song = meta_curr_song
            ptable[controller_pos_hash].volume = volume
            ptable[controller_pos_hash].speakers = {}
            play_song_for_player(pname, controller_pos, ptable[controller_pos_hash], volume, song, connected_speakers)
        else
            ptable[controller_pos_hash] = nil
        end
    elseif ptable[controller_pos_hash] and volume ~= ptable[controller_pos_hash].volume then
        -- Keep some distance between frequent volume updates
        -- So old ones doesn't override new ones
        local now = os.time()
        local volume_last_update = ptable[controller_pos_hash].volume_last_update
        if not volume_last_update or now - volume_last_update >= 1 then
            ptable[controller_pos_hash].volume_last_update = now
            return
        end

        logger:action("Phonograph at %s volume changed to %s%%, updating audio for %s",
            PS(controller_pos), volume, pname)
        for _, data in ipairs(connected_speakers) do
            local speaker_pos = data[1]
            local speaker_pos_hash = core.hash_node_position(speaker_pos)
            local handle = ptable[controller_pos_hash].speakers[speaker_pos_hash]
            if handle then
                local target_volume = data[3] * volume / 10000
                local original_volume = data[3] * ptable[controller_pos_hash].volume / 10000
                local delta_volume = math.abs(target_volume - original_volume)
                core.sound_fade(handle, delta_volume, target_volume) -- Called fade but can also increase
            end
        end
        ptable[controller_pos_hash].volume = volume
    elseif not ptable[controller_pos_hash]
        and vector_distance(ppos, controller_pos) <= phonograph.START_HEARING_DISTANCE then
        if song then
            local state = phonograph.send_song(player, meta_curr_song, channels_to_send)
            if state then
                logger:action("Phonograph at %s is playing %s at volume %s%%, playing for %s",
                    PS(controller_pos), meta_curr_song, volume, pname)
                ptable[controller_pos_hash] = {
                    curr_song = meta_curr_song,
                    volume = volume,
                    speakers = {},
                }
                play_song_for_player(
                    pname, controller_pos, ptable[controller_pos_hash], volume, song, connected_speakers)
            end
        else
            logger:action("Phonograph at %s is playing %s but it is not avaliable, " ..
                "playing for %s failed",
                PS(controller_pos), meta_curr_song, pname)
            phonograph.set_song(controller_meta, "")
        end
    end
end

modlib.minetest.register_globalstep(0.5, function()
    for _, player in ipairs(core.get_connected_players()) do
        local pname = player:get_player_name()
        local ppos = player:get_pos()

        if not phonograph.players[pname] then
            phonograph.players[pname] = {}
        end
        local ptable = phonograph.players[pname]

        local minp = vector.add(ppos, phonograph.STOP_HEARING_DISTANCE)
        local maxp = vector.add(ppos, -phonograph.STOP_HEARING_DISTANCE)

        local visited = {}
        for _, controller_pos in ipairs(core.find_nodes_in_area(minp, maxp, "group:phonograph_controller", false)) do
            local controller_pos_hash = core.hash_node_position(controller_pos)
            process_one_phonograph(controller_pos, controller_pos_hash, player, pname, ppos, ptable)
            visited[controller_pos_hash] = true
        end

        for controller_pos_hash in pairs(ptable) do
            if not visited[controller_pos_hash] then
                -- Must be too far away or no longer a phonograph
                logger:action("Player %s is too far away from phonograph at %s, fading audio.",
                    pname, PS(core.get_position_from_hash(controller_pos_hash)))
                fade_controller_for_player(ptable, controller_pos_hash)
                ptable[controller_pos_hash] = nil
            end
        end
    end
end)

-- remove sound handlers on leave
core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    logger:action(("Player %s leaving, removing handler reference."):format(
        name
    ))
    phonograph.players[name] = nil
end)

-- Cut out the audio of a phonograph immediately
function phonograph.stop_phonograph(pos)
    local hash = core.hash_node_position(pos)
    for name, data in pairs(phonograph.players) do
        if data[hash] then
            logger:action(("Phonograph at %s no longer exists, stopping audio for %s"):format(
                PS(pos), name
            ))
            fade_controller_for_player(data, hash)
            data[hash] = nil
        end
    end
end

if core.get_modpath("background_music") then
    -- Supress background music if active phonograph within 20m
    -- 21~32m: NVM just let them overlay

    background_music.register_on_decide_music(function(player)
        local name = player:get_player_name()
        local ppos = player:get_pos()
        if phonograph.players[name] then
            for hash in pairs(phonograph.players[name]) do
                local pos = core.get_position_from_hash(hash)
                if vector_distance(ppos, pos) <= 20 then
                    return "null", 10000
                end
            end
        end
    end)
end
