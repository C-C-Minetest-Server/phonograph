-- phonograph/phonograph_core/src/licenses.lua
-- License elements
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

local S = phonograph.internal.S

local licenses = {}
phonograph.licenses = licenses

licenses.CC0 = function(song, album)
    return S("This work by @1 is marked with CC0 1.0. To view a copy of this license, visit @2",
        song.artist or album.artist or S("Unknown artist"),
        "https://creativecommons.org/publicdomain/zero/1.0/")
end

licenses.CCBYSA3 = function(song, album)
    return S("This work by @1 is licensed under @2. To view a copy of this license, visit @3",
        song.artist or album.artist or S("Unknown artist"),
        "CC BY-SA 3.0",
        "https://creativecommons.org/licenses/by-sa/3.0/")
end

licenses.CCBY4 = function(song, album)
    return S("This work by @1 is licensed under @2. To view a copy of this license, visit @3",
        song.artist or album.artist or S("Unknown artist"),
        "CC BY 4.0",
        "https://creativecommons.org/licenses/by/4.0/")
end

licenses.CCBYSA4 = function(song, album)
    return S("This work by @1 is licensed under @2. To view a copy of this license, visit @3",
        song.artist or album.artist or S("Unknown artist"),
        "CC BY-SA 4.0",
        "https://creativecommons.org/licenses/by-sa/4.0/")
end
