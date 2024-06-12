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

-- Return the sound parameter table for a phonograph
function phonograph.get_parameters(pos, name)
    return {
        pos = pos,
        loop = true,
        to_player = name,
    }
end

-- Return true if a player can interact with that phonograph
function phonograph.check_interact_privs(name, pos)
    if type(name) ~= "string" then
        name = name:get_player_name()
    end

    if minetest.is_protected(pos, name) and not minetest.check_player_privs(name, { protection_bypass = true }) then
        return false
    end

    local node = minetest.get_node(pos)
    if node.name ~= "phonograph:phonograph" then
        return false
    end

    return true
end

function phonograph.set_song(meta, song_name)
    meta:set_string("curr_song", song_name)
    phonograph.update_meta(meta)
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
            meta:set_string("song_title", minetest.get_translated_string("en", song.title or "Untitled"))
            meta:set_string("song_artist", minetest.get_translated_string("en", song.artist or album.artist or "Unknown artist"))
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
