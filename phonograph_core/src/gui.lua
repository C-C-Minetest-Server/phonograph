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
    none = function(player, ctx)
        return gui.VBox {
            min_h = 9, min_w = 6,
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
    album = function(player, ctx)
        local album = phonograph.registered_albums[ctx.selected_album]
        if not album then
            return gui.VBox {
                min_h = 9, min_w = 6,
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
            min_h = 9, min_w = 8,
            gui.HBox {
                gui.Image {
                    w = 2, h = 2,
                    texture_name = album.cover or "phonograph_node_temp_ok.png",
                },
                gui.VBox {
                    gui.Label {
                        label = album.title or S("Untitled")
                    },
                    gui.Label {
                        label = album.artist or S("Unknown artist")
                    },
                    gui.Label {
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
                min_h = 9, min_w = 6,
                gui.Image {
                    w = 3, h = 3,
                    texture_name = "phonograph_node_temp_error.png",
                    expand = true, align_h = "center", align_v = "center",
                },
                gui.Label {
                    label = S("ERROR: Song @1 not found.", ctx.selected_song),
                    expand = true, align_h = "center", align_v = "center",
                }
            }
        end

        ctx.selected_album = song.album
        local album = phonograph.registered_albums[song.album]
        if not album then
            return gui.VBox {
                min_h = 7, min_w = 6,
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

        local meta = minetest.get_meta(ctx.pos)

        return gui.VBox {
            min_h = 9, min_w = 6,
            gui.VBox {
                gui.HBox {
                    gui.VBox {
                        gui.Label {
                            label = song.title or S("Untitled")
                        },
                        gui.Label {
                            label = song.artist or album.artist or S("Unknown artist")
                        },
                        gui.Label {
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
                    label = song.long_description or S("No descriptions given."),
                },
                phonograph.check_interact_privs(player, ctx.pos) and (
                    (meta:get_string("curr_song") == ctx.selected_song) and gui.Button {
                        -- is the playing song
                        w = 1.5, h = 1,
                        label = S("Stop"),
                        expand = true, align_h = "right", align_v = "bottom",
                        on_event = function(player, ctx)
                            if not phonograph.check_interact_privs(player, ctx.pos) then return true end

                            local meta = minetest.get_meta(ctx.pos)
                            meta:set_string("curr_song", "")
                            phonograph.update_meta(meta)

                            return true
                        end,
                    } or gui.Button {
                        -- not the playing song
                        w = 1.5, h = 1,
                        label = S("Play"),
                        expand = true, align_h = "right", align_v = "bottom",
                        on_event = function(player, ctx)
                            if not phonograph.check_interact_privs(player, ctx.pos) then return true end

                            local meta = minetest.get_meta(ctx.pos)
                            meta:set_string("curr_song", ctx.selected_song)
                            phonograph.update_meta(meta)

                            return true
                        end
                    }) or gui.Nil {},
            },
        }
    end
}

local generate_albums_list = function(player, ctx)
    local button_list = {}
    for _, name in pairs(phonograph.registered_albums_keys) do
        local def = phonograph.registered_albums[name]
        button_list[#button_list+1] = gui.HBox {
            gui.Image {
                w = 1, h = 1,
                texture_name = def.cover or "phonograph_node_temp_ok.png",
                align_h = "left",
            },
            gui.Button {
                w = 4,
                label = def.short_title or def.title or S("Untitled"),
                on_event = function(player, ctx)
                    ctx.selected_album = name
                    ctx.selected_song = nil
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

local generate_songs_list = function(player, ctx)
    local button_list = {}
    for _, name in ipairs(phonograph.songs_in_album[ctx.selected_album] or {}) do
        local def = phonograph.registered_songs[name]
        button_list[#button_list+1] = gui.Button {
            w = 4, h = 1,
            label = def.short_title or def.title or S("Untitled"),
            on_event = function(player, ctx)
                ctx.selected_song = name
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

    if not (ctx.selected_album or ctx.selected_song) then
        local meta = minetest.get_meta(ctx.pos)
        local meta_curr_song = meta:get_string("curr_song")
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
