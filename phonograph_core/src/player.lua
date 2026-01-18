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

-- key: player name
-- value: { <coord_hash> = { curr_song = <song_id>, handle = <handle> } }
phonograph.players = {}

modlib.minetest.register_globalstep(0.5, function()
    for _, player in ipairs(core.get_connected_players()) do
        local pname = player:get_player_name()
        local ppos = player:get_pos()

        if not phonograph.players[pname] then
            phonograph.players[pname] = {}
        end
        local ptable = phonograph.players[pname]

        local minp, maxp = vector.add(ppos, 32), vector.add(ppos, -32)
        local visited = {}
        for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, "phonograph:phonograph", false)) do
            local hash = core.hash_node_position(pos)
            local meta = core.get_meta(pos)
            local meta_curr_song = meta:get_string("curr_song")

            if meta_curr_song == "" then
                if ptable[hash] then
                    logger:action(("Phonograph at %s is not playing anything, fading audio for %s"):format(
                        PS(pos), pname
                    ))
                    core.sound_fade(ptable[hash].handle, 0.5, 0)
                    ptable[hash] = nil
                end
            elseif ptable[hash] and meta_curr_song ~= ptable[hash].curr_song then
                core.sound_fade(ptable[hash].handle, 0.5, 0)
                local song = phonograph.registered_songs[meta_curr_song]
                if not song then
                    logger:action(("Phonograph at %s is playing %s but it is not avaliable, " ..
                        "fading audio for %s and stopping phonograph."):format(
                        PS(pos), meta_curr_song, pname
                    ))
                    core.sound_fade(ptable[hash].handle, 0.5, 0)
                    ptable[hash][hash] = nil
                    phonograph.set_song(meta, "")
                elseif phonograph.send_song(player, meta_curr_song) then
                    logger:action(("Phonograph at %s is playing %s, changing the audio of %s"):format(
                        PS(pos), meta_curr_song, pname
                    ))
                    ptable[hash].curr_song = meta_curr_song
                    ptable[hash].handle = core.sound_play(song.spec, phonograph.get_parameters(pos, pname))
                else
                    logger:action(("Phonograph at %s is playing %s, sending audio for %s"):format(
                        PS(pos), meta_curr_song, pname
                    ))
                    ptable[hash] = nil
                end
            elseif not ptable[hash] and vector_distance(ppos, pos) <= 15 then
                local song = phonograph.registered_songs[meta_curr_song]
                if song then
                    local state = phonograph.send_song(player, meta_curr_song)
                    if state then
                        logger:action(("Phonograph at %s is playing %s, playing for %s"):format(
                            PS(pos), meta_curr_song, pname
                        ))
                        ptable[hash] = {
                            curr_song = meta_curr_song,
                            handle = core.sound_play(song.spec, phonograph.get_parameters(pos, pname)),
                        }
                    elseif state == nil then
                        logger:action(("Phonograph at %s is playing %s, sending audio for %s"):format(
                            PS(pos), meta_curr_song, pname
                        ))
                    end
                else
                    logger:action(("Phonograph at %s is playing %s but it is not avaliable, " ..
                        "playing for %s failed"):format(
                        PS(pos), meta_curr_song, pname
                    ))
                    phonograph.set_song(meta, "")
                end
            end

            visited[hash] = true
        end

        for hash, data in pairs(ptable) do
            if not visited[hash] then
                -- Must be too far away or no longer a phonograph
                logger:action(("Player %s is too far away from phonograph at %s, fading audio."):format(
                    pname, PS(core.get_position_from_hash(hash))
                ))
                core.sound_fade(data.handle, 0.5, 0)
                ptable[hash] = nil
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
            core.sound_stop(data[hash].handle)
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
