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
local FS = function(...) return core.formspec_escape(S(...)) end

local dig_groups = { oddly_breakable_by_hand = 3 } -- A must-work group (cf. Void game)
local sounds = nil

if core.get_modpath("default") then
    -- Use Minetest Game groups
    logger:action("Using Minetest Game node definitions and crafting recipies.")
    dig_groups = { choppy = 2, oddly_breakable_by_hand = 2, flammable = 2 }
    sounds = default.node_sound_wood_defaults()

    core.register_craft({
        output = "phonograph:phonograph",
        recipe = {
            { "group:wood", "group:wood",      "group:wood" },
            { "group:wood", "default:diamond", "group:wood" },
            { "group:wood", "group:wood",      "group:wood" },
        }
    })

    core.register_craft({
        output = "phonograph:phonograph_controller",
        recipe = {
            { "group:wood", "group:wood",      "group:wood" },
            { "group:wood", "default:gold_ingot", "group:wood" },
            { "group:wood", "group:wood",      "group:wood" },
        }
    })

    core.register_craft({
        output = "phonograph:phonograph_speaker",
        recipe = {
            { "group:wood", "group:wood",      "group:wood" },
            { "group:wood", "default:steel_ingot", "group:wood" },
            { "group:wood", "group:wood",      "group:wood" },
        }
    })
elseif core.get_modpath("hades_core") and core.get_modpath("hades_sounds") then
    -- Use Hades Revisited groups
    logger:action("`Using Hades Revisited node definitions and crafting recipies.")
    dig_groups = { choppy = 3, oddly_breakable_by_hand = 2, flammable = 3 }
    sounds = hades_sounds.node_sound_wood_defaults()

    core.register_craft({
        output = "phonograph:phonograph",
        recipe = {
            { "group:wood", "group:wood",         "group:wood" },
            { "group:wood", "hades_core:diamond", "group:wood" },
            { "group:wood", "group:wood",         "group:wood" },
        }
    })

    core.register_craft({
        output = "phonograph:phonograph_controller",
        recipe = {
            { "group:wood", "group:wood",      "group:wood" },
            { "group:wood", "hades_core:gold_ingot", "group:wood" },
            { "group:wood", "group:wood",      "group:wood" },
        }
    })

    core.register_craft({
        output = "phonograph:phonograph_speaker",
        recipe = {
            { "group:wood", "group:wood",      "group:wood" },
            { "group:wood", "hades_core:steel_ingot", "group:wood" },
            { "group:wood", "group:wood",      "group:wood" },
        }
    })
end

local phonograph_def = {
    description = S("Phonograph"),
    tiles = { "phonograph_node_temp.png" },
    groups = table.copy(dig_groups),
    sounds = sounds,

    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_string("infotext", S("Idle Phonograph"))
    end,
    on_destruct = function(pos)
        phonograph.stop_phonograph(pos)
    end,
    on_rightclick = function(pos, _, player)
        phonograph.node_gui:show(player, { pos = pos })
    end,
}
phonograph_def.groups.phonograph_speaker = 2    -- Is a speaker and the controller is itself
phonograph_def.groups.phonograph_controller = 2 -- Is a controller and the speaker is itself
core.register_node(":phonograph:phonograph", phonograph_def)

local CONTROLLER_LINK_FORMSPEC =
    "field[channel_id;" ..
    FS("Channel to play (mono, left, right)") ..
    ";]"

local last_interacted_phonograph_speaker = {}

local phonograph_controller_def = {
    description = S("Phonograph Controller"),
    tiles = { "phonograph_node_temp.png" },
    groups = table.copy(dig_groups),
    sounds = sounds,

    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_string("infotext", S("Idle Phonograph"))
    end,
    on_destruct = function(pos)
        phonograph.stop_phonograph(pos)
        phonograph.controller_disconnect_all_from_controller(pos)
    end,
    on_rightclick = function(pos, _, player)
        phonograph.node_gui:show(player, { pos = pos })
    end,

    on_punch = function(pos, _, puncher)
        if not puncher:is_player() then return end
        local name = puncher:get_player_name()
        if not last_interacted_phonograph_speaker[name] then return end
        if core.is_protected(pos, name) then
            core.record_protection_violation(pos, name)
            return
        end

        local speaker_pos = last_interacted_phonograph_speaker[name]
        core.show_formspec(
            name,
            "phonograph:controller_link:" .. table.concat({
                speaker_pos.x, speaker_pos.y, speaker_pos.z,
                pos.x, pos.y, pos.z
            }, ","),
            CONTROLLER_LINK_FORMSPEC)
        last_interacted_phonograph_speaker[name] = nil
    end,
}
phonograph_controller_def.groups.phonograph_controller = 1 -- Is a normal controller
core.register_node(":phonograph:phonograph_controller", phonograph_controller_def)

local phonograph_speaker_def = {
    description = S("Phonograph Speaker"),
    tiles = { "phonograph_node_temp_ok.png" },
    groups = table.copy(dig_groups),
    sounds = sounds,

    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_string("infotext", S("Disconnected Phonograph Speaker"))
    end,
    on_destruct = function(pos)
        phonograph.speaker_do_disconnect(pos)

        for name, d_pos in pairs(last_interacted_phonograph_speaker) do
            if vector.equals(pos, d_pos) then
                last_interacted_phonograph_speaker[name] = nil
            end
        end
    end,

    on_punch = function(pos, _, puncher)
        if not puncher:is_player() then return end
        local name = puncher:get_player_name()
        if core.is_protected(pos, name) then
            core.record_protection_violation(pos, name)
            return
        end

        last_interacted_phonograph_speaker[name] = pos
        core.chat_send_player(name, S("Punch a phonograph controller to connect this speaker."))
    end,
}
phonograph_speaker_def.groups.phonograph_speaker = 1 -- Is a normal speaker
core.register_node(":phonograph:phonograph_speaker", phonograph_speaker_def)

core.register_on_player_receive_fields(function(player, formname, fields)
    if string.sub(formname, 0, 27) ~= "phonograph:controller_link:" then return end

    local name = player:get_player_name()
    local pos_data = string.sub(formname, 28)
    local pos_parts = string.split(pos_data, ",")
    local speaker_pos_x, speaker_pos_y, speaker_pos_z =
        tonumber(pos_parts[1]), tonumber(pos_parts[2]), tonumber(pos_parts[3])
    local controller_pos_x, controller_pos_y, controller_pos_z =
        tonumber(pos_parts[4]), tonumber(pos_parts[5]), tonumber(pos_parts[6])
    if speaker_pos_x == nil or speaker_pos_y == nil or speaker_pos_z == nil
            or controller_pos_x == nil or controller_pos_y == nil or controller_pos_z == nil then
        return
    end
    local speaker_pos = vector.new(speaker_pos_x, speaker_pos_y, speaker_pos_z)
    local controller_pos = vector.new(controller_pos_x, controller_pos_y, controller_pos_z)

    if core.is_protected(speaker_pos, name) then
        core.record_protection_violation(speaker_pos, name)
        return
    end
    if core.is_protected(controller_pos, name) then
        core.record_protection_violation(controller_pos, name)
        return
    end

    local speaker_node = core.get_node(speaker_pos)
    local speaker_type = core.get_item_group(speaker_node.name, "phonograph_speaker")
    if speaker_type ~= 1 then
        return false
    end

    local controller_node = core.get_node(controller_pos)
    local controller_type = core.get_item_group(controller_node.name, "phonograph_controller")
    if controller_type ~= 1 then
        return false
    end

    local channel = fields.channel_id
    channel = channel and string.trim(channel)
    if not channel or channel == "" then
        core.chat_send_player(name, S("Invalid channel ID!"))
        return
    elseif channel == "mono" then
        channel = -1
    elseif channel == "left" then
        channel = 0
    elseif channel == "right" then
        channel = 1
    end
    channel = tonumber(channel)
    if channel == nil then
        core.chat_send_player(name, S("Invalid channel ID!"))
        return
    end

    phonograph.speaker_do_disconnect(speaker_pos)
    if phonograph.controller_connect_to_speaker(controller_pos, speaker_pos, channel) then
        core.chat_send_player(name, S("Successfully connected @1 to @2 on channel #@3",
            core.pos_to_string(speaker_pos), core.pos_to_string(speaker_pos), channel))
    end
end)

core.register_on_leaveplayer(function(player)
    last_interacted_phonograph_speaker[player:get_player_name()] = nil
end)