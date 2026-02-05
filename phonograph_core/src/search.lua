-- phonograph/phonograph_core/src/search.lua
-- Search functions
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

local function find_in_haystack(haystacks, query, player_lang)
    for _, haystack in ipairs(haystacks) do
        if type(haystack) == "string" then
            local text_en = core.get_translated_string("en", haystack):lower()
            if text_en:find(query, 1, true) then
                return true
            end

            if player_lang and player_lang ~= "en" then
                local text_localized = core.get_translated_string(player_lang, haystack):lower()
                if text_localized ~= text_en and text_localized:find(query, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

function phonograph.search_in_albums(query, player_lang)
    query = query:trim():lower()

    local albums_matching = {}
    for album_name, album in pairs(phonograph.registered_albums) do
        local haystacks = {
            album_name,
            album.title,
            album.artist,
            album.short_title,
            album.short_description,
            album.long_description,
        }
        if find_in_haystack(haystacks, query, player_lang) then
            albums_matching[#albums_matching + 1] = album_name
        end
    end

    table.sort(albums_matching)
    return albums_matching
end

function phonograph.search_in_songs(query, player_lang)
    query = query:trim():lower()

    local songs_matching = {}
    for song_name, song in pairs(phonograph.registered_songs) do
        local real_name = song_name
        if song.album and string.sub(real_name, 1, #song.album) == song.album then
            real_name = string.sub(real_name, #song.album + 1)
        end
        local haystacks = {
            real_name,
            song.title,
            song.artist,
            song.short_title,
            song.short_description,
            song.long_description,
        }
        if find_in_haystack(haystacks, query, player_lang) then
            songs_matching[#songs_matching + 1] = song_name
        end
    end

    table.sort(songs_matching)
    return songs_matching
end
