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

local logger = phonograph.internal.logger:sublogger("functions")
local S = phonograph.internal.S
local PS = minetest.pos_to_string

-- key: player name
-- value: { <coord_hash> = { curr_song = <song_id>, handle = <handle> } }
phonograph.players = {}

-- Return the sound parameter table for a phonograph
function phonograph.get_parameters(pos, name)
    return {
        pos = pos,
        loop = true,
        to_player = name,
    }
end

-- Cut out the audio of a phonograph immediately
function phonograph.stop_phonograph(pos)
    local hash = minetest.hash_node_position(pos)
    for name, data in pairs(phonograph.players) do
        if data[hash] then
            logger:action(("Phonograph at %s no longer exists, stopping audio for %s"):format(
                PS(pos), name
            ))
            minetest.sound_stop(data[hash].handle)
            data[hash] = nil
        end
    end
end

local function pos_dist(pos1, pos2)
    return math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2 + (pos1.z - pos2.z)^2)
end

local passed = 0
minetest.register_globalstep(function(dtime)
    passed = passed + dtime
    if passed < 0.5 then return end
    passed = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local ppos = player:get_pos()
        local checked = {}

        if phonograph.players[name] then
            for hash, data in pairs(phonograph.players[name]) do
                checked[hash] = true
                local pos = minetest.get_position_from_hash(hash)

                local node = minetest.get_node(pos)
                if pos_dist(pos, ppos) > 32 then -- Check if the player is too far away
                    logger:action(("Player %s is too far away from phonograph at %s, fading audio."):format(
                        name, PS(pos)
                    ))
                    minetest.sound_fade(data.handle, 0.5, 0)
                    phonograph.players[name][hash] = nil
                elseif node.name ~= "phonograph:phonograph" then -- Check if that node is still a phonograph
                    logger:action(("Phonograph at %s no longer exists, fading audio for %s"):format(
                        PS(pos), name
                    ))
                    minetest.sound_fade(data.handle, 0.5, 0)
                    phonograph.players[name][hash] = nil
                else
                    -- Check if the song played is still the same
                    local meta = minetest.get_meta(pos)
                    local meta_curr_song = meta:get_string("curr_song")
                    if meta_curr_song == "" then
                        logger:action(("Phonograph at %s is not playing anything, fading audio for %s"):format(
                            PS(pos), name
                        ))
                        minetest.sound_fade(data.handle, 0.5, 0)
                        phonograph.players[name][hash] = nil
                    elseif meta_curr_song ~= data.curr_song then
                        minetest.sound_fade(data.handle, 0.5, 0)
                        local song = phonograph.registered_songs[meta_curr_song]
                        if not song then
                            logger:action(("Phonograph at %s is playing %s but it is not avaliable, " ..
                                "fading audio for %s"):format(
                                PS(pos), meta_curr_song, name
                            ))
                            minetest.sound_fade(data.handle, 0.5, 0)
                            phonograph.players[name][hash] = nil
                        else
                            logger:action(("Phonograph at %s is playing %s, changing the audio of %s"):format(
                                PS(pos), meta_curr_song, name
                            ))
                            data.curr_song = meta_curr_song
                            data.handle = minetest.sound_play(song.spec, phonograph.get_parameters(pos, name))
                        end
                    end
                end
            end
        end
        local pos1 = vector.add(ppos, 15)
        local pos2 = vector.add(ppos, -15)
        for _, pos in ipairs(minetest.find_nodes_in_area(pos1, pos2, "phonograph:phonograph", false)) do
            local hash = minetest.hash_node_position(pos)
            if not checked[hash] then
                -- Check if sound is actually playing
                local meta = minetest.get_meta(pos)
                local meta_curr_song = meta:get_string("curr_song")
                if meta_curr_song ~= "" then
                    local song = phonograph.registered_songs[meta_curr_song]
                    if not song then
                        logger:action(("Phonograph at %s is playing %s but it is not avaliable, " ..
                            "playing for %s failed"):format(
                            PS(pos), meta_curr_song, name
                        ))
                    else
                        logger:action(("Phonograph at %s is playing %s, playing for %s"):format(
                            PS(pos), meta_curr_song, name
                        ))
                        phonograph.players[name] = phonograph.players[name] or {}
                        phonograph.players[name][hash] = {
                            curr_song = meta_curr_song,
                            handle = minetest.sound_play(song.spec, phonograph.get_parameters(pos, name)),
                        }
                    end
                end
            end
        end
    end
end)

-- remove sound handlers on leave
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    logger:action(("Player %s leaving, removing handler reference."):format(
        name
    ))
    phonograph.players[name] = nil
end)


-- Return true if a player can interact with that phonograph
function phonograph.check_interact_privs(name, pos)
    if type(name) ~= "string" then
        name = name:get_player_name()
    end

    if minetest.is_protected(pos, name) and not minetest.check_player_privs(name { protection_bypass = true }) then
        return false
    end

    local node = minetest.get_node(pos)
    if node.name ~= "phonograph:phonograph" then
        return false
    end

    return true
end

function phonograph.update_meta(meta)
    local curr_song = meta:get_string("curr_song")
    if curr_song == "" then
        meta:set_string("infotext", S("Idle Phonograph"))
    else
        local song = phonograph.registered_songs[curr_song]
        if song then
            meta:set_string("infotext", S("Phonograph") .. "\n" .. S("Playing: @1", song.title or S("Untitled")))
        else
            meta:set_string("infotext", S("Idle Phonograph") .. "\n" .. S("Invalid soundtrack"))
        end
    end
end