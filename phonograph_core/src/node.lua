-- phonograph/phonograph_core/src/node.lua
-- Regsiter node
-- depends: gui
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

local logger = phonograph.internal.logger:sublogger("node")
local S = phonograph.internal.S

-- A must-work group (cf. Void game)
local groups = { oddly_breakable_by_hand = 3 }
local sounds = nil
if minetest.get_modpath("default") then
    -- Use Minetest Game groups
    logger:action("Using Minetest Game node definitions and crafting recipies.")
    groups = { choppy = 2, oddly_breakable_by_hand = 2, flammable = 2 }
    sounds = default.node_sound_wood_defaults()

    minetest.register_craft({
        output = "phonograph:phonograph",
        recipe = {
            { "group:wood", "group:wood",    "group:wood" },
            { "group:wood", "default:diamond", "group:wood" },
            { "group:wood", "group:wood",    "group:wood" },
        }
    })
elseif minetest.get_modpath("hades_core") and minetest.get_modpath("hades_sounds") then
    -- Use Hades Revisited groups
    logger:action("`Using Hades Revisited node definitions and crafting recipies.")
    groups = { choppy = 3, oddly_breakable_by_hand = 2, flammable = 3 }
    sounds = hades_sounds.node_sound_wood_defaults()

    minetest.register_craft({
        output = "phonograph:phonograph",
        recipe = {
            { "group:wood", "group:wood",    "group:wood" },
            { "group:wood", "hades_core:diamond", "group:wood" },
            { "group:wood", "group:wood",    "group:wood" },
        }
    })
end

minetest.register_node(":phonograph:phonograph", {
    description = S("Phonograph"),
    tiles = { "phonograph_node_temp.png" },
    groups = groups,
    sounds = sounds,
    on_rightclick = function(pos, node, player)
        phonograph.node_gui:show(player, { pos = pos })
    end,
    after_destruct = function(pos)
        phonograph.check_handle(pos)
    end,
})