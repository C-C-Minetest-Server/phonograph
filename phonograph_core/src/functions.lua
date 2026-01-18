-- phonograph/phonograph_core/src/functions.lua
-- Core functions
-- depends: registrations
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

-- local logger = phonograph.internal.logger:sublogger("functions")
local S = phonograph.internal.S

-- Return the sound parameter table for a phonograph
function phonograph.get_parameters(pos, name, max_hear_distance)
    return {
        pos = pos,
        loop = true,
        to_player = name,
        max_hear_distance = max_hear_distance or 32,
    }
end

-- Return true if a player can interact with that phonograph
function phonograph.check_interact_privs(name, pos)
    if type(name) ~= "string" then
        name = name:get_player_name()
    end

    if core.is_protected(pos, name) and not core.check_player_privs(name, { protection_bypass = true }) then
        return false
    end

    local node = core.get_node(pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")
    if controller_type == 0 then
        return false
    end

    return true
end

function phonograph.set_song(meta, song_name)
    meta:set_string("curr_song", song_name)
    phonograph.update_meta(meta)
end

function phonograph.controller_get_connected_speakers(pos)
    local node = core.get_node(pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")

    if controller_type == 1 then
        local meta = core.get_meta(pos)

        local connected_speakers_raw = meta:get_string("phonograph_connected_speakers")
        local connected_speakers = connected_speakers_raw ~= "" and core.deserialize(connected_speakers_raw, true)

        return connected_speakers or {}
    elseif controller_type == 2 then
        return { { pos, -1 } }
    end

    return {}
end

function phonograph.controller_connect_to_speaker(pos, speaker_pos, channel)
    local node = core.get_node(pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")

    if controller_type ~= 1 then
        return false
    end

    local speaker_node = core.get_node(speaker_pos)
    local speaker_type = core.get_item_group(speaker_node.name, "phonograph_speaker")

    if speaker_type ~= 1 then
        return false
    end

    local speaker_meta = core.get_meta(speaker_pos)
    speaker_meta:set_int("phonograph_controller_pos_x", pos.x)
    speaker_meta:set_int("phonograph_controller_pos_y", pos.y)
    speaker_meta:set_int("phonograph_controller_pos_z", pos.z)
    speaker_meta:set_string("infotext", S("Connected Phonograph Speaker: @1 on @2",
        core.pos_to_string(pos), channel >= 0 and ("multichannel #" .. channel) or "mono"))

    local meta = core.get_meta(pos)
    local connected_speakers = phonograph.controller_get_connected_speakers(pos)

    for _, data in ipairs(connected_speakers) do
        if vector.equals(data[1], speaker_pos) then
            data[2] = channel
            meta:set_string("phonograph_connected_speakers", core.serialize(connected_speakers))
            return true
        end
    end

    connected_speakers[#connected_speakers+1] = { {
        x = speaker_pos.x,
        y = speaker_pos.y,
        z = speaker_pos.z,
    }, channel }
    meta:set_string("phonograph_connected_speakers", core.serialize(connected_speakers))
    return true
end

function phonograph.controller_disconnect_speaker_from_controller(controller_pos, speaker_pos)
    local node = core.get_node(controller_pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")

    if controller_type ~= 1 then
        return false
    end

    local speaker_meta = core.get_meta(speaker_pos)
    speaker_meta:set_string("phonograph_controller_pos_x", "")
    speaker_meta:set_string("phonograph_controller_pos_y", "")
    speaker_meta:set_string("phonograph_controller_pos_z", "")
    speaker_meta:set_string("infotext", S("Disconnected Phonograph Speaker"))

    local meta = core.get_meta(controller_pos)
    local connected_speakers = phonograph.controller_get_connected_speakers(controller_pos)
    for i, data in ipairs(connected_speakers) do
        if vector.equals(data[1], speaker_pos) then
            table.remove(connected_speakers, i)
            local serialized = #connected_speakers > 0 and core.serialize(connected_speakers) or ""
            meta:set_string("phonograph_connected_speakers", serialized)
            return
        end
    end
end

function phonograph.controller_disconnect_all_from_controller(pos)
    local node = core.get_node(pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")

    if controller_type ~= 1 then
        return false
    end

    local connected_speakers = phonograph.controller_get_connected_speakers(pos)
    for _, data in ipairs(connected_speakers) do
        local speaker_pos = data[1]
        local speaker_meta = core.get_meta(speaker_pos)
        speaker_meta:set_string("phonograph_controller_pos_x", "")
        speaker_meta:set_string("phonograph_controller_pos_y", "")
        speaker_meta:set_string("phonograph_controller_pos_z", "")
        speaker_meta:set_string("infotext", S("Disconnected Phonograph Speaker"))
    end

    local meta = core.get_meta(pos)
    meta:set_string("phonograph_connected_speakers", "")
end

function phonograph.speaker_do_disconnect(pos)
    local meta = core.get_meta(pos)
    local x = meta:contains("phonograph_controller_pos_x") and meta:get_int("phonograph_controller_pos_x") or nil
    local y = meta:contains("phonograph_controller_pos_y") and meta:get_int("phonograph_controller_pos_y") or nil
    local z = meta:contains("phonograph_controller_pos_z") and meta:get_int("phonograph_controller_pos_z") or nil

    if x and y and z then
        local controller_pos = vector.new(x, y, z)
        phonograph.stop_phonograph(controller_pos)     -- TODO: (Probably) only stop this speaker
        phonograph.controller_disconnect_speaker_from_controller(controller_pos, pos)
    end
end


function phonograph.update_meta(meta)
    local curr_song = meta:get_string("curr_song")

    if curr_song == "" then
        meta:set_string("infotext", S("Idle Phonograph"))
        meta:set_string("song_title", "")
        meta:set_string("song_artist", "")
    else
        local song = phonograph.registered_songs[curr_song]
        local album = phonograph.registered_albums[song.album] or {}
        if song then
            meta:set_string("infotext", S("Phonograph") .. "\n" .. S("Playing: @1", song.title or S("Untitled")))
            meta:set_string("song_title", core.get_translated_string("en", song.title or "Untitled"))
            meta:set_string("song_artist",
                core.get_translated_string("en", song.artist or album.artist or "Unknown artist"))
        else
            meta:set_string("infotext", S("Idle Phonograph") .. "\n" .. S("Invalid soundtrack"))
            meta:set_string("song_title", "")
            meta:set_string("song_artist", "")
        end
    end

    meta:mark_as_private({
        "curr_song",
        "song_title",
        "song_artist"
    })
end
