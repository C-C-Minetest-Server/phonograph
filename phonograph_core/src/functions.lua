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
local PS = minetest.pos_to_string

-- key: Coordinate hash
-- value: { curr_song = id, handle = handle }
phonograph.phonographs = {}

-- Return the sound parameter table for a phonograph
function phonograph.get_parameters(pos)
    return {
        pos = pos,
        loop = true,
    }
end

-- Check the status of the playing handle of a phonograph
-- 1. If no songs is set: fade the existing one out if any
-- 2. If song set but is not the one played: fade the existing one and play the new one
-- 3. If song set and nothing is playing: play the new opne
-- 4. If song set and is the same as the one played: Do nothing and quit
function phonograph.check_handle(pos)
    local hash = minetest.hash_node_position(pos)
    local node = minetest.get_node(pos)
    if node.name ~= "phonograph:phonograph" then
        if phonograph.phonographs[hash] then
            logger:action(("Phonograph at %s no longer exists. Cutting its audio out."):format(PS(pos)))
            minetest.sound_stop(phonograph.phonographs[hash].handle)
            phonograph.phonographs[hash] = nil
        end
        return
    end

    local pause = true
    for _, object in ipairs(minetest.get_objects_inside_radius(pos, 32)) do
        if object:is_player() then
            pause = false
            break
        end
    end
    if pause then
        if phonograph.phonographs[hash] then
            logger:action(("Phonograph at %s is unloaded, pausing it."):format(PS(pos)))
            minetest.sound_fade(phonograph.phonographs[hash].handle, 0.5, 0)
            phonograph.phonographs[hash] = nil
        end
        return
    end

    local meta = minetest.get_meta(pos)
    local meta_curr_song = meta:get_string("curr_song")

    -- If no songs is set (or one was unset)
    if meta_curr_song == "" then
        if phonograph.phonographs[hash] then
            logger:action(("Phonograph at %s is playing sound without songs set, fading it out."):format(PS(pos)))
            minetest.sound_fade(phonograph.phonographs[hash].handle, 0.5, 0)
            phonograph.phonographs[hash] = nil
        end
        return
    end

    if phonograph.phonographs[hash] then
        if phonograph.phonographs[hash].curr_song == meta_curr_song then
            -- Nothing to do; quitting
            return
        end

        -- Reaching this means a mismatch between handler and metadata
        logger:action(("Phonograph at %s is playing %s but the new one is %s. Fading the old one out."):format(
            PS(pos), phonograph.phonographs[hash].curr_song, meta_curr_song
        ))
        minetest.sound_fade(phonograph.phonographs[hash].handle, 0.5, 0)
    end

    if not phonograph.registered_songs[meta_curr_song] then
        logger:action(("Phonograph at %s attempts to play %s but it is not avaliable."):format(
            PS(pos), meta_curr_song
        ))
        return
    end

    logger:action(("Playing %s on phonograph at %s"):format(meta_curr_song, PS(pos)))
    phonograph.phonographs[hash] = {
        curr_song = meta_curr_song,
        handle = minetest.sound_play(phonograph.registered_songs[meta_curr_song].spec, phonograph.get_parameters(pos))
    }
end

-- Restart unloaded phonographs
minetest.register_abm({
    label = "Restart unloaded phonographs",
    name = "phonograph_core:restart_phonographs",
    nodenames = { "phonograph:phonograph" },
    chance = 1,
    interval = 5,
    action = function(pos)
        phonograph.check_handle(pos)
    end
})

-- Pause phonographs in unloaded mapblocks
do
    local function loop()
        for hash, data in pairs(phonograph.phonographs) do
            local pos = minetest.get_position_from_hash(hash)
            phonograph.check_handle(pos)
        end

        minetest.after(5, loop)
    end

    minetest.after(5, loop)
end

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
