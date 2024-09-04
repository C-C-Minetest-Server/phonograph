-- phonograph/phonograph_core/src/gui.lua
-- GUI of phonograph node
-- depends: functions, registrations
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

local logger = phonograph.internal.logger:sublogger("gui")
local gui = flow.widgets
local S = phonograph.internal.S

local get_page_content = {
    none = function()
        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.Image {
                w = 3, h = 3,
                texture_name = "phonograph_node_temp.png",
                expand = true, align_h = "center", align_v = "center",
            },
            gui.Label {
                label = S("Select an album to start exploring the universe of songs"),
                expand = true, align_h = "center", align_v = "center",
            }
        }
    end,
    album = function(_, ctx)
        local album = phonograph.registered_albums[ctx.selected_album]
        if not album then
            return gui.VBox {
                min_h = 10, min_w = 9,
                gui.Image {
                    w = 3, h = 3,
                    texture_name = "phonograph_node_temp_error.png",
                    expand = true, align_h = "center", align_v = "center",
                },
                gui.Label {
                    label = S("ERROR: Album @1 not found.", ctx.selected_album),
                    expand = true, align_h = "center", align_v = "center",
                }
            }
        end

        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.HBox {
                gui.Image {
                    w = 2, h = 2,
                    texture_name = album.cover or "phonograph_node_temp_ok.png",
                },
                gui.VBox {
                    gui.Label {
                        max_w = 6, w = 6,
                        label = album.title or S("Untitled")
                    },
                    gui.Label {
                        max_w = 6, w = 6,
                        label = album.artist or S("Unknown artist")
                    },
                    gui.Label {
                        max_w = 6, w = 6,
                        label = album.short_description or ""
                    },
                },
            },
            gui.Textarea {
                max_w = 5.5, w = 5.5, h = 6,
                label = album.long_description or S("No descriptions given."),
            }
        }
    end,
    song = function(player, ctx)
        local song = phonograph.registered_songs[ctx.selected_song]
        if not song then
            return gui.VBox {
                min_h = 10, min_w = 9,
                gui.Image {
                    w = 3, h = 3,
                    texture_name = "phonograph_node_temp_error.png",
                    expand = true, align_h = "center", align_v = "center",
                },
                gui.Label {
                    max_w = 8, w = 8,
                    label = S("ERROR: Song @1 not found.", ctx.selected_song),
                    expand = true, align_h = "center", align_v = "center",
                }
            }
        end

        ctx.selected_album = song.album
        local album = phonograph.registered_albums[song.album]
        if not album then
            return gui.VBox {
                min_h = 10, min_w = 9,
                gui.Image {
                    w = 3, h = 3,
                    texture_name = "phonograph_node_temp_error.png",
                    expand = true, align_h = "center", align_v = "center",
                },
                gui.Label {
                    max_w = 8, w = 8,
                    label = S("ERROR: Album @1 not found.", ctx.selected_album),
                    expand = true, align_h = "center", align_v = "center",
                }
            }
        end

        local meta = minetest.get_meta(ctx.pos)
        local license = song.license or album.license
        if not license then
            license = S("No license information given.")
        elseif type(license) == "function" then
            license = license(song, album)
        end

        local songs_downloading = phonograph.get_downloading_songs(player:get_player_name())

        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.VBox {
                gui.HBox {
                    gui.VBox {
                        gui.Label {
                            max_w = 6, w = 6,
                            label = song.title or S("Untitled")
                        },
                        gui.Label {
                            max_w = 6, w = 6,
                            label = song.artist or album.artist or S("Unknown artist")
                        },
                        gui.Label {
                            max_w = 6, w = 6,
                            label = song.short_description or ""
                        },
                    },
                    gui.Image {
                        w = 2, h = 2,
                        texture_name = album.cover or "phonograph_node_temp_ok.png",
                        expand = true, align_h = "right",
                    },
                },
                gui.Textarea {
                    max_w = 5.5, w = 5.5, h = 6,
                    label =
                        (song.long_description or S("No descriptions given.")) .. "\n\n" .. license,
                },
                gui.Hbox {
                    (#songs_downloading ~= 0) and gui.Label {
                        max_w = 4, w = 4, h = 1,
                        label = (#songs_downloading == 1)
                            and S("Downloading @1", phonograph.registered_songs[songs_downloading[1]].title)
                            or S("Downloading @1 songs", #songs_downloading),
                    } or gui.Nil {},
                    phonograph.check_interact_privs(player, ctx.pos) and (
                        (meta:get_string("curr_song") == ctx.selected_song) and gui.Button {
                            -- is the playing song
                            w = 1.5, h = 1,
                            label = S("Stop"),
                            expand = true, align_h = "right", align_v = "bottom",
                            on_event = function(eplayer, ectx)
                                if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end

                                local emeta = minetest.get_meta(ectx.pos)
                                phonograph.set_song(emeta, "")

                                phonograph.node_gui:update_where(function(uplayer, uctx)
                                    return vector.equals(uctx.pos, ectx.pos)
                                        and uplayer:get_player_name() ~= eplayer:get_player_name()
                                end)

                                return true
                            end,
                        } or gui.Button {
                            -- not the playing song
                            w = 1.5, h = 1,
                            label = S("Play"),
                            expand = true, align_h = "right", align_v = "bottom",
                            on_event = function(eplayer, ectx)
                                if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end

                                local emeta = minetest.get_meta(ectx.pos)
                                phonograph.set_song(emeta, ctx.selected_song)

                                phonograph.node_gui:update_where(function(uplayer, uctx)
                                    return vector.equals(uctx.pos, ectx.pos)
                                        and uplayer:get_player_name() ~= eplayer:get_player_name()
                                end)

                                return true
                            end
                        }) or gui.Nil {},
                },
            },
        }
    end
}

local generate_albums_list = function(_, ctx)
    local button_list = {}
    for _, name in pairs(phonograph.registered_albums_keys) do
        local def = phonograph.registered_albums[name]
        local title = def.short_title or def.title or S("Untitled")
        if ctx.selected_album == name then
            title = minetest.get_color_escape_sequence("yellow") .. title
        elseif ctx.curr_album == name then
            title = minetest.get_color_escape_sequence("orange") .. title
        end
        button_list[#button_list+1] = gui.HBox {
            gui.Image {
                w = 1, h = 1,
                texture_name = def.cover or "phonograph_node_temp_ok.png",
                align_h = "left",
            },
            gui.Button {
                w = 4,
                label = title,
                on_event = function(_, ectx)
                    ectx.selected_album = name
                    ectx.selected_song = nil
                    return true
                end,
            },
        }
    end
    button_list.name = "svb_album_list"
    button_list.w = 5.3
    button_list.h = 9
    return gui.ScrollableVBox(button_list)
end

local generate_songs_list = function(_, ctx)
    local button_list = {}
    for _, name in ipairs(phonograph.songs_in_album[ctx.selected_album] or {}) do
        local def = phonograph.registered_songs[name]
        local title = def.short_title or def.title or S("Untitled")
        if ctx.selected_song == name then
            title = minetest.get_color_escape_sequence("yellow") .. title
        elseif ctx.curr_song == name then
            title = minetest.get_color_escape_sequence("orange") .. title
        end
        button_list[#button_list+1] = gui.Button {
            w = 4, h = 1,
            label = title,
            on_event = function(_, ectx)
                ectx.selected_song = name
                return true
            end,
        }
    end
    button_list.name = "svb_songs_list"
    button_list.w = 4.5
    button_list.h = 9
    return gui.ScrollableVBox(button_list)
end

phonograph.node_gui = flow.make_gui(function(player, ctx)
    logger:assert(ctx.pos, "`ctx` without `pos` passed into phonograph.node_gui")

    local node = minetest.get_node(ctx.pos)
    if node.name ~= "phonograph:phonograph" then
        return gui.VBox {
            min_h = 9, min_w = 6,
            gui.Image {
                w = 3, h = 3,
                texture_name = "phonograph_node_temp_error.png",
                expand = true, align_h = "center", align_v = "center",
            },
            gui.Label {
                label = S("ERROR: The node at @1 is not a phonograph.", minetest.pos_to_string(ctx.pos)),
                expand = true, align_h = "center", align_v = "center",
            },
            gui.ButtonExit {
                label = S("Exit")
            },
        }
    end


    local meta = minetest.get_meta(ctx.pos)
    ctx.curr_song = meta:get_string("curr_song")
    ctx.curr_album = (phonograph.registered_songs[ctx.curr_song] or {}).album or ""
    if not (ctx.selected_album or ctx.selected_song) then
        local meta_curr_song = ctx.curr_song
        if meta_curr_song ~= "" then
            ctx.selected_song = meta_curr_song
        end
    end

    local tab_func = get_page_content.none
    if ctx.selected_song then
        tab_func = get_page_content.song
    elseif ctx.selected_album then
        tab_func = get_page_content.album
    end
    -- This also prepares some variable
    local tab_content = tab_func(player, ctx)

    return gui.VBox {
        gui.HBox {
            gui.Label {
                label = S("Phonograph"),
                expand = true, align_h = "left"
            },
            gui.ButtonExit {
                w = 0.5, h = 0.5,
                label = "x",
            },
        },
        gui.Box { w = 0.05, h = 0.05, color = "grey" },

        gui.HBox {
            generate_albums_list(player, ctx),
            generate_songs_list(player, ctx),
            tab_content
        }
    }
end)
