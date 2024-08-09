-- phonograph/phonograph_core/init.lua
-- Nodes, registerations, mechanics
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

phonograph = {}
phonograph.internal = {
    logger = logging.logger("phonograph.core"),
    S = minetest.get_translator("phonograph_core")
}


local MP = minetest.get_modpath("phonograph_core")
for _, name in ipairs({
    "registrations",
    "functions", -- depends: registrations
    "dynamic",   -- depends: registrations
    "player",    -- depends: functions, settings, dynamic
    "gui",       -- depends: functions, registrations
    "node",      -- depends: gui
    "teacher",
}) do
    dofile(MP .. "/src/" .. name .. ".lua")
end

phonograph.internal = nil
