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

if not core.features.dynamic_add_media_table then
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

-- song_state[player_name][song_name][channel_id]
-- channel_id: -1 (mono), 0+ (stereo/multichannel)
local songs_state = {}

core.register_on_leaveplayer(function(player)
    songs_state[player:get_player_name()] = nil
end)

--[[function phonograph.send_song(player, song_name)
    local name = player:get_player_name()
    local def = phonograph.registered_songs[song_name]
    if not def then
        return false
    elseif not def.spec.filepath then
        return true
    end
    if not songs_state[name] then
        songs_state[name] = {}
    end
    if songs_state[name][song_name] == nil then
        songs_state[name][song_name] = false
        core.dynamic_add_media({
            filepath = def.spec.filepath,
            to_player = name,
        }, function()
            if not songs_state[name] then return end
            logger:action(("Sent song %s to player %s"):format(song_name, name))
            songs_state[name][song_name] = true

            local cb_player = core.get_player_by_name(name)
            if cb_player then
                phonograph.node_gui:update(cb_player)
            end
        end)
        phonograph.node_gui:update(player)
        return nil
    end
    return songs_state[name][song_name]
end]]

function phonograph.send_song(player, song_name, channels)
    local name = player:get_player_name()
    local def = phonograph.registered_songs[song_name]
    if not def then
        return false
    end
    if not songs_state[name] then
        songs_state[name] = {}
    end
    if not songs_state[name][song_name] then
        songs_state[name][song_name] = {}
    end

    if not channels or #channels == 0 then
        channels = { -1 }
    end

    local sent = true
    for _, channel in ipairs(channels) do
        local channel_spec = channel >= 0 and def.multichannel_specs[channel] or def.spec
        if not channel_spec then return false end

        if channel_spec.filepath and not songs_state[name][song_name][channel] then
            logger:action("Sending song %s spec \"%s\" to player %s",
                song_name, channel >= 0 and ("multichannel #" .. channel) or "mono", name)
            songs_state[name][song_name][channel] = false
            sent = nil
            core.dynamic_add_media({
                filepath = channel_spec.filepath,
                to_player = name,
            }, function()
                if not songs_state[name] or not songs_state[name][song_name] then return end
                songs_state[name][song_name][channel] = true
                logger:action("Sent song %s spec \"%s\" to player %s",
                    song_name, channel >= 0 and ("multichannel #" .. channel) or "mono", name)

                for _, cb_channel in ipairs(channels) do
                    if songs_state[name][song_name][cb_channel] ~= true then
                        return
                    end
                end

                local cb_player = core.get_player_by_name(name)
                phonograph.node_gui:update(cb_player)
            end)
        end
    end

    if not sent then phonograph.node_gui:update(player) end
    return sent
end

function phonograph.get_downloading_songs(name)
    if not songs_state[name] then
        return {}
    end

    local rtn = {}
    for song, chn_data in pairs(songs_state[name]) do
        for _, state in pairs(chn_data) do
            if state == false then
                rtn[#rtn+1] = song
                break
            end
        end
    end
    return rtn
end

core.register_chatcommand("inspect_song_state", {
    func = function()
        return true, dump(songs_state)
    end,
})