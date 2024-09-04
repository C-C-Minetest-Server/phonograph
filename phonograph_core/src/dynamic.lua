-- phonograph/phonograph_core/src/dynamic.lua
-- Handle dynamic add media
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

if not minetest.features.dynamic_add_media_table then
    -- If we reached this, there must be no dynamic songs,
    -- or an error would have been raised in registerations.lua
    function phonograph.send_song()
        return true
    end

    function phonograph.get_downloading_songs()
        return {}
    end

    return
end

local logger = phonograph.internal.logger:sublogger("dynamic")

local songs_state = {}

minetest.register_on_leaveplayer(function(player)
    songs_state[player:get_player_name()] = nil
end)

function phonograph.send_song(player, song_name)
    local name = player:get_player_name()
    local def = phonograph.registered_songs[song_name]
    if not def then
        return false
    elseif not def.filepath then
        return true
    end
    if not songs_state[name] then
        songs_state[name] = {}
    end
    if songs_state[name][song_name] == nil then
        songs_state[name][song_name] = false
        minetest.dynamic_add_media({
            filepath = def.filepath,
            to_player = name,
        }, function()
            if not songs_state[name] then return end
            logger:action(("Sent song %s to player %s"):format(song_name, name))
            songs_state[name][song_name] = true

            local cb_player = minetest.get_player_by_name(name)
            if cb_player then
                phonograph.node_gui:update(cb_player)
            end
        end)
        phonograph.node_gui:update(player)
        return nil
    end
    return songs_state[name][song_name]
end

function phonograph.get_downloading_songs(name)
    if not songs_state[name] then
        return {}
    end

    local rtn = {}
    for song, state in pairs(songs_state[name]) do
        if state == false then
            rtn[#rtn+1] = song
        end
    end
    return rtn
end
