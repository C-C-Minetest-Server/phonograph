-- phonograph/phonograph_album_white/init.lua
-- White noise album
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

local S = core.get_translator("phonograph_album_white")

local album = phonograph.register_album("phonograph_album_white:album_white", {
    short_title = S("World of White"),
    title = S("Wonders of Randoms: World of White"),
    short_description = S("Relaxing noises for testing purpose"),
    long_description = S("Oh, so relaxing! A bug-free world starts from a test case."),
    cover = "phonograph_album_white_cover.png",
    artist = "/dev/random", -- Not translated on purpose
})

album:register_song("white", {
    title = S("Pure White Noise"),
    short_description = S("20 seconds of white noise"),
    long_description = "ffmpeg -f lavfi -i anoisesrc=c=white:r=48000 -t 20", -- Not translated on purpose
    artist = "anoise", -- Not translated on purpose
    filepath = table.concat({
        core.get_modpath("phonograph_album_white"),
        "phonographs",
        "phonograph_album_white_song_white.ogg"
    }, DIR_DELIM),
    spec = { -- a SimpleSoundSpec
        gain = 0.3
    },
    license = phonograph.licenses.CC0,
})
