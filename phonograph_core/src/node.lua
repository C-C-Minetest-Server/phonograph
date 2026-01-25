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
        type = "shapeless",
        output = "phonograph:phonograph_controller",
        recipe = { "phonograph:phonograph", "default:gold_ingot" },
    })

    core.register_craft({
        type = "shapeless",
        output = "phonograph:phonograph_speaker",
        recipe = { "phonograph:phonograph", "default:steel_ingot" },
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
        type = "shapeless",
        output = "phonograph:phonograph_controller",
        recipe = { "phonograph:phonograph", "hades_core:gold_ingot" },
    })

    core.register_craft({
        type = "shapeless",
        output = "phonograph:phonograph_speaker",
        recipe = { "phonograph:phonograph", "hades_core:steel_ingot" },
    })
end

-- Common

local CONTROLLER_LINK_FORMSPEC =
    "field[channel_id;" ..
    FS("Channel to play (mono, left, right)") ..
    ";]"
local CONTROLLER_VOLU_FORMSPEC =
    "field[sound_volume;" ..
    FS("Volume (0 < volume <= 100)%") ..
    ";]"

function phonograph.phonograph_on_construct(pos)
    local meta = core.get_meta(pos)
    return meta:set_string("infotext", S("Idle Phonograph"))
end

function phonograph.phonograph_on_rightclick(pos, _, player)
    phonograph.node_gui:show(player, { pos = pos })
end

-- Simple only

function phonograph.simple_phonograph_on_construct(pos)
    return phonograph.stop_phonograph(pos)
end

-- Controller only

local last_interacted_phonograph_speaker = {}

function phonograph.controller_on_destruct(pos)
    phonograph.stop_phonograph(pos)
    phonograph.controller_disconnect_all_from_controller(pos)
end

-- Speakers only

function phonograph.speaker_on_construct(pos)
    local meta = core.get_meta(pos)
    return meta:set_string("infotext", S("Disconnected Phonograph Speaker"))
end

function phonograph.speaker_on_destruct(pos)
    phonograph.speaker_do_disconnect(pos)

    for name, d_pos in pairs(last_interacted_phonograph_speaker) do
        if vector.equals(pos, d_pos) then
            last_interacted_phonograph_speaker[name] = nil
        end
    end
end

function phonograph.register_simple_phonograph(name, def)
    if string.sub(name, 1, 1) ~= ":" then
        name = ":" .. name
    end
    def = table.copy(def)

    def.groups = def.groups or {}
    def.groups.phonograph_speaker = 2    -- Is a speaker and the controller is itself
    def.groups.phonograph_controller = 2 -- Is a controller and the speaker is itself

    def.on_construct = phonograph.phonograph_on_construct
    def.on_destruct = phonograph.simple_phonograph_on_construct
    def.on_rightclick = phonograph.phonograph_on_rightclick

    return core.register_node(name, def)
end

function phonograph.register_phonograph_controller(name, def)
    if string.sub(name, 1, 1) ~= ":" then
        name = ":" .. name
    end
    def = table.copy(def)

    def.groups = def.groups or {}
    def.groups.phonograph_controller = 1 -- Is a normal controller

    def.on_construct = phonograph.phonograph_on_construct
    def.on_destruct = phonograph.controller_on_destruct
    def.on_rightclick = phonograph.phonograph_on_rightclick

    return core.register_node(name, def)
end

function phonograph.register_phonograph_speaker(name, def)
    if string.sub(name, 1, 1) ~= ":" then
        name = ":" .. name
    end
    def = table.copy(def)

    def.groups = def.groups or {}
    def.groups.phonograph_speaker = 1 -- Is a normal speaker

    def.on_construct = phonograph.speaker_on_construct
    def.on_destruct = phonograph.speaker_on_destruct

    return core.register_node(name, def)
end

phonograph.register_simple_phonograph("phonograph:phonograph", {
    description = S("Phonograph"),
    tiles = { "phonograph_node_temp.png" },
    sounds = sounds,
    groups = dig_groups,
})

phonograph.register_phonograph_controller("phonograph:phonograph_controller", {
    description = S("Phonograph Controller"),
    tiles = { "phonograph_node_temp.png" },
    sounds = sounds,
    groups = dig_groups,
})

phonograph.register_phonograph_speaker("phonograph:phonograph_speaker", {
    description = S("Phonograph Speaker"),
    tiles = { "phonograph_node_temp_ok.png" },
    sounds = sounds,
    groups = dig_groups,
})

core.register_on_punchnode(function(pos, node, puncher)
    if not puncher:is_player() then return end
    local name = puncher:get_player_name()

    local node_name = node.name

    if core.get_item_group(node_name, "phonograph_speaker") == 1 then
        if core.is_protected(pos, name) then
            core.record_protection_violation(pos, name)
            return
        end
        last_interacted_phonograph_speaker[name] = pos
        core.chat_send_player(name, S("Punch a phonograph controller to connect this speaker."))
    elseif core.get_item_group(node_name, "phonograph_controller") == 1 then
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
    elseif last_interacted_phonograph_speaker[name] then
        last_interacted_phonograph_speaker[name] = nil
        core.chat_send_player(name, S("Not a phonograph controller, cancelling."))
    end
end)

core.register_on_player_receive_fields(function(player, formname, fields)
    local sub_name = string.sub(formname, 0, 27)
    if sub_name ~= "phonograph:controller_link:" and sub_name ~= "phonograph:controller_volu:" then
        return
    end

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

    if sub_name == "phonograph:controller_link:" then
        local channel = fields.channel_id
        channel = type(channel) == "string" and channel:lower():trim()
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

        core.show_formspec(
            name,
            "phonograph:controller_volu:" .. table.concat({
                speaker_pos.x, speaker_pos.y, speaker_pos.z,
                controller_pos.x, controller_pos.y, controller_pos.z,
                channel
            }, ","),
            CONTROLLER_VOLU_FORMSPEC)
    elseif sub_name == "phonograph:controller_volu:" then
        local channel = tonumber(pos_parts[7])
        if channel == nil then return end

        local volume = tonumber(fields.sound_volume)
        if volume == nil or volume <= 0 or volume > 100 then
            core.chat_send_player(name, S("Volume not supplied or out of range!"))
            return
        end

        phonograph.stop_phonograph(controller_pos)
        phonograph.speaker_do_disconnect(speaker_pos)
        if phonograph.controller_connect_to_speaker(controller_pos, speaker_pos, channel, volume) then
            core.chat_send_player(name, S("Successfully connected @1 to @2 on @3 at volume @4%",
                core.pos_to_string(speaker_pos), core.pos_to_string(speaker_pos),
                phonograph.get_channel_name(channel), volume))
        end
    end
end)

core.register_on_leaveplayer(function(player)
    last_interacted_phonograph_speaker[player:get_player_name()] = nil
end)
