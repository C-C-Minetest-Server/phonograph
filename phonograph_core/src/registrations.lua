-- phonograph/phonograph_core/src/registrations.lua
-- Register albums and songs
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

local logger = phonograph.internal.logger:sublogger("registrations")

phonograph.registered_albums = {}
phonograph.registered_songs = {}
phonograph.songs_in_album = {}

function phonograph.validate_spec(name, desc, spec)
    logger:assert(type(spec) == "table",
        "Validation of song %s spec \"%s\" failed: invalid type (\"table\" expected, got \"%s\")",
        name, desc, type(spec))
    if spec.gain then
        logger:assert(type(spec.gain) == "number",
            "Validation of song %s spec \"%s\" failed: invalid `spec.gain` field type " ..
            "(\"number\" or \"nil\" expected, got \"%s\")",
            name, desc, type(spec.gain))
        logger:assert(spec.gain >= 0,
            "Validation of song %s spec \"%s\" failed: invalid `spec.gain` field value " ..
            "(non-negative number expected, got \"%s\")",
            name, desc, spec.gain)
    end
    if spec.pitch then
        logger:assert(type(spec.pitch) == "number",
            "Validation of song %s spec \"%s\" failed: invalid `spec.pitch` field type " ..
            "(\"number\" or \"nil\" expected, got \"%s\")",
            name, desc, type(spec.pitch))
        logger:assert(spec.pitch >= 0,
            "Validation of song %s spec \"%s\" failed: invalid `spec.pitch` field value " ..
            "(non-negative number expected, got \"%s\")",
            name, desc, spec.pitch)
    end
    if spec.fade then
        logger:assert(type(spec.fade) == "number",
            "Validation of song %s spec \"%s\" failed: invalid `spec.fade` field type " ..
            "(\"number\" or \"nil\" expected, got \"%s\")",
            name, desc, type(spec.fade))
        logger:assert(spec.fade >= 0,
            "Validation of song %s spec \"%s\" failed: invalid `spec.fade` field value " ..
            "(non-negative number expected, got \"%s\")",
            name, desc, spec.fade)
    end
    if spec.filepath then
        logger:assert(core.features.dynamic_add_media_table,
            "Song %s spec \"%s\" is not compactible with this Minetest version. " ..
            "Please upgrade Minetest to 5.5.0 or later versions.",
            name, desc)
        logger:assert(type(spec.filepath) == "string",
            "Validation of song %s spec \"%s\" failed: invalid `spec.filepath field type " ..
            "(\"string\" expected, got \"%s\")",
            name, desc, type(spec.filepath))
        local file = io.open(spec.filepath, "rb")
        logger:assert(file,
            "Validation of song %s spec \"%s\" failed: invalid `spec.filepath` field value " ..
            "(File \"%s\" not found)",
            name, desc, spec.filepath)
        file:close()
        local filename = spec.filepath:match("[^/]*.ogg$")
        assert(filename,
            "Validation of song %s spec \"%s\" failed: invalid `spec.filepath` field value " ..
            "(File \"%s\" does not end with .ogg)",
            name, desc, spec.filepath)
        spec.name = filename:sub(1, #filename - 4)
    end

    logger:assert(type(spec.name) == "string",
        "Validation of song %s spec \"%s\" failed: invalid `spec.name` field type (\"string\" expected, got \"%s\")",
        name, desc, type(spec.name))
end

-- Validation of song definitions
-- Mainly checks the SimpleSoundSpec (def.spec)
function phonograph.validate_song(name, def)
    logger:assert(type(def) == "table",
        "Validation of song %s failed: invalid definition table type (\"table\" expected, got \"%s\")",
        name, type(def))

    if def.filepath then
        def.spec.filepath = def.filepath
        def.filepath = nil
    end

    phonograph.validate_spec(name, "mono", def.spec)

    -- Stereo or multi-channel validation
    if def.multichannel_specs then
        logger:assert(type(def.multichannel_specs) == "table",
            "Validation of song %s failed: invalid `multichannel_spec` field type " ..
            "(\"table\" or \"nil\" expected, got \"%s\")",
            name, type(def.spec))

        logger:assert(#def.multichannel_specs >= 2,
            "Validation of song %s failed: Number of specs in `multichannel_spec` must be at least 2",
            name)

        for i, spec in ipairs(def.multichannel_specs) do
            phonograph.validate_spec(name, "multichannel #" .. i, spec)
        end
    end
end

-- Register a song
function phonograph.register_song(name, def)
    phonograph.validate_song(name, def)
    phonograph.registered_songs[name] = def

    if def.album then
        if not phonograph.songs_in_album[def.album] then
            phonograph.songs_in_album[def.album] = {}
        end
        phonograph.songs_in_album[def.album][#phonograph.songs_in_album[def.album] + 1] = name
    end
end

local album_functions = {
    register_song = function(self, name, def)
        if not self.album_id then
            logger:raise("Attempt to call register_song on an invalid album object")
        end

        name = self.album_id .. ":" .. name
        def.album = self.album_id

        return phonograph.register_song(name, def)
    end
}

-- Register an album
-- This returns an object with :register_song registering songs in the album.
function phonograph.register_album(name, def)
    phonograph.registered_albums[name] = def

    return setmetatable({ album_id = name }, {
        __index = album_functions,
        __newindex = function()
            logger:raise("Attempt to set new field on an album object")
        end
    })
end

phonograph.registered_albums_keys = {}
core.register_on_mods_loaded(function()
    for key, _ in pairs(phonograph.registered_albums) do
        phonograph.registered_albums_keys[#phonograph.registered_albums_keys + 1] = key
    end
    table.sort(phonograph.registered_albums_keys)
end)
