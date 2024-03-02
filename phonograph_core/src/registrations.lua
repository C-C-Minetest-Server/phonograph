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

-- Validation of song definitions
-- Mainly checks the SimpleSoundSpec (def.spec)
function phonograph.validate_song(name, def)
    logger:assert(type(def) == "table",
        ("Validation of song %s failed: invalid definition table type (\"table\" expected, got \"%s\")"):format(
            name, type(def)
        )
    )
    logger:assert(type(def.spec) == "table",
        ("Validation of song %s failed: invalid `spec` field type (\"table\" expected, got \"%s\")"):format(
            name, type(def.spec)
        )
    )

    logger:assert(type(def.spec.name) == "string",
        ("Validation of song %s failed: invalid `spec.name` field type (\"string\" expected, got \"%s\")"):format(
            name, type(def.spec.name)
        )
    )
    if def.spec.gain then
        logger:assert(type(def.spec.gain) == "number",
            ("Validation of song %s failed: invalid `spec.gain` field type " ..
                "(\"number\" or \"nil\" expected, got \"%s\")"):format(
                name, type(def.spec.gain)
            )
        )
        logger:assert(def.spec.gain >= 0,
            ("Validation of song %s failed: invalid `spec.gain` field value " ..
                "(non-negative number expected, got \"%s\")"):format(
                name, def.spec.gain
            )
        )
    end
    if def.spec.pitch then
        logger:assert(type(def.spec.pitch) == "number",
            ("Validation of song %s failed: invalid `spec.pitch` field type " ..
                "(\"number\" or \"nil\" expected, got \"%s\")"):format(
                name, type(def.spec.pitch)
            )
        )
        logger:assert(def.spec.pitch >= 0,
            ("Validation of song %s failed: invalid `spec.pitch` field value " ..
                "(non-negative number expected, got \"%s\")"):format(
                name, def.spec.pitch
            )
        )
    end
    if def.spec.fade then
        logger:assert(type(def.spec.fade) == "number",
            ("Validation of song %s failed: invalid `spec.fade` field type " ..
                "(\"number\" or \"nil\" expected, got \"%s\")"):format(
                name, type(def.spec.fade)
            )
        )
        logger:assert(def.spec.fade >= 0,
            ("Validation of song %s failed: invalid `spec.fade` field value " ..
                "(non-negative number expected, got \"%s\")"):format(
                name, def.spec.fade
            )
        )
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
        phonograph.songs_in_album[def.album][#phonograph.songs_in_album[def.album]+1] = name
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
