-- phonograph/phonograph_core/src/teacher.lua
-- Teacher integration
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

if not minetest.global_exists("teacher") then return end

local S = phonograph.internal.S

teacher.register_turorial("phonograph:tutorial_phonograph", {
    title = S("Phonograph"),
    triggers = {
        {
            name = "approach_node",
            nodenames = "phonograph:phonograph",
        },
        {
            name = "obtain_item",
            itemname = "phonograph:phonograph",
        }
    },

    {
        texture = "phonograph_tutorial_1.png",
        text =
            S("The Phonograph plays music to players around it. " ..
                "When the player approaches it, the sound is played. When the player leaves, the sound ceases."),
    },
    {
        texture = "phonograph_tutorial_2.png",
        text =
            S("Right-click a Phonograph to set its soundtrack. " ..
                "After selecting the soundtrack from the left panels, press \"Play\" to start the track.")
    },
})
