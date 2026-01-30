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

local teacher_exists = core.global_exists("teacher") and true or false

local function get_volume_widget(ctx)
    local meta = core.get_meta(ctx.pos)
    local volume = meta:get_int("sound_volume")
    if volume == 0 then
        volume = 100
        phonograph.set_volume(meta, 100)
    end

    local function change_volume(eplayer, ectx, offset)
        if volume + offset > 100 or volume + offset <= 0 then
            return
        end

        volume = volume + offset
        phonograph.set_volume(meta, volume)

        phonograph.node_gui:update_where(function(uplayer, uctx)
            return vector.equals(uctx.pos, ectx.pos)
                and uplayer:get_player_name() ~= eplayer:get_player_name()
        end)

        return true
    end

    return gui.VBox {
        gui.HBox {
            max_w = 2.5, max_h = 0.5, h = 0.5,
            align_h = "center",
            gui.Label {
                max_w = 1, w = 1, max_h = 0.5, h = 0.5,
                label = S("Volume:")
            },
            gui.Button {
                max_w = 0.5, max_h = 0.5, w = 0.5, h = 0.5,
                label = "-",
                on_event = function(eplayer, ectx)
                    return change_volume(eplayer, ectx, -5)
                end,
            },
            gui.Label {
                max_w = 0.5, w = 0.5, max_h = 0.5, h = 0.5,
                label = volume .. "%",
            },
            gui.Button {
                max_w = 0.5, max_h = 0.5, w = 0.5, h = 0.5,
                label = "+",
                on_event = function(eplayer, ectx)
                    return change_volume(eplayer, ectx, 5)
                end,
            },
        },
    }
end

local function error_page(message)
    return gui.VBox {
        min_h = 10, min_w = 9,
        gui.Image {
            w = 3, h = 3,
            texture_name = "phonograph_node_temp_error.png",
            expand = true, align_h = "center", align_v = "center",
        },
        gui.Label {
            label = S("Error: @1", message),
            expand = true, align_h = "center", align_v = "center",
        }
    }
end

local get_page_content = {
    -- Default interface
    none = function()
        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.Image {
                w = 3, h = 3,
                texture_name = "phonograph_node_temp.png",
                expand = true, align_h = "center", align_v = "center",
            },
            gui.Label {
                label = S("Select an album to start exploring the universe of songs."),
                expand = true, align_h = "center", align_v = "center",
            }
        }
    end,

    -- Special pages
    config = function(player, ctx)
        if not phonograph.check_interact_privs(player, ctx.pos) then
            return error_page(S("You do not have permission to configure this phonograph."))
        end

        local config_displays = {}

        -- Connected Speakers
        local controller_type = core.get_item_group(core.get_node(ctx.pos).name, "phonograph_controller")
        if controller_type == 1 then
            local connected_speakers = phonograph.controller_get_connected_speakers(ctx.pos)
            local speaker_lines = {}

            speaker_lines[#speaker_lines + 1] = gui.Box { w = 0.05, h = 0.05, color = "grey" }
            speaker_lines[#speaker_lines + 1] = gui.HBox {
                gui.Label {
                    max_w = 2, w = 2,
                    max_h = 0.5, h = 0.5,
                    label = S("Speaker Position"),
                    style = {
                        font = "bold",
                    },
                },
                gui.Label {
                    max_w = 1, w = 1,
                    max_h = 0.5, h = 0.5,
                    label = S("Channel"),
                    style = {
                        font = "bold",
                    },
                },
                gui.Label {
                    max_w = 1, w = 1,
                    max_h = 0.5, h = 0.5,
                    label = S("Volume"),
                    style = {
                        font = "bold",
                    },
                },
            }
            speaker_lines[#speaker_lines + 1] = gui.Box { w = 0.05, h = 0.05, color = "grey" }
            for _, spec in ipairs(connected_speakers) do
                local speaker_pos = spec[1]
                local channel = spec[2]
                local volume = spec[3] or 100
                speaker_lines[#speaker_lines + 1] = gui.HBox {
                    gui.Label {
                        max_w = 2, w = 2,
                        max_h = 0.5, h = 0.5,
                        label = core.pos_to_string(speaker_pos),
                    },
                    gui.Label {
                        max_w = 1, w = 1,
                        max_h = 0.5, h = 0.5,
                        label = phonograph.get_channel_name(channel),
                    },
                    gui.Label {
                        max_w = 1, w = 1,
                        max_h = 0.5, h = 0.5,
                        label = tostring(volume),
                    },
                    gui.Button {
                        max_w = 1.5, w = 1.5,
                        max_h = 0.5, h = 0.5,
                        label = S("Disconnect"),
                        on_event = function(eplayer, ectx)
                            if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end
                            phonograph.stop_phonograph(ectx.pos)
                            phonograph.controller_disconnect_speaker_from_controller(ectx.pos, speaker_pos)
                            phonograph.node_gui:update_where(function(uplayer, uctx)
                                return vector.equals(uctx.pos, ectx.pos)
                                    and uplayer:get_player_name() ~= eplayer:get_player_name()
                            end)
                            return true
                        end,
                    },
                }
                speaker_lines[#speaker_lines + 1] = gui.Box { w = 0.05, h = 0.05, color = "grey" }
            end

            if #connected_speakers == 0 then
                speaker_lines[#speaker_lines + 1] = gui.Label {
                    label = S("No connected speakers. Punch a speaker and then punch the controller to connect it."),
                    expand = true, align_h = "center",
                }
                speaker_lines[#speaker_lines + 1] = gui.Box { w = 0.05, h = 0.05, color = "grey" }
            end

            config_displays[#config_displays + 1] = gui.VBox {
                gui.Label {
                    label = S("Connected Speakers"),
                    expand = true, align_h = "left",
                    style = {
                        font = "bold",
                        font_size = "*1.5"
                    },
                },
                unpack(speaker_lines),
            }
        else
            config_displays[#config_displays + 1] = gui.VBox {
                gui.Label {
                    w = 5, max_w = 5,
                    label = S("Connected Speakers"),
                    expand = true, align_h = "left",
                    style = {
                        font = "bold",
                        font_size = "*1.5"
                    },
                },
                gui.Label {
                    w = 5, max_w = 5,
                    label = S("This controller integrates a speaker in itself. " ..
                        "Use a phonograph controller for multiple speakers."),
                    expand = true, align_h = "center",
                },
            }
        end

        -- Digiline channel
        do
            config_displays[#config_displays + 1] = gui.VBox {
                gui.Label {
                    w = 5, max_w = 5,
                    label = S("Digiline Channel"),
                    expand = true, align_h = "left",
                    style = {
                        font = "bold",
                        font_size = "*1.5"
                    },
                },
                gui.HBox {
                    gui.Field {
                        w = 3, max_w = 3, h = 0.7, max_h = 0.7,
                        name = "config_digiline_channel",
                        default = core.get_meta(ctx.pos):get_string("channel") or "",
                        on_key_enter = function(eplayer, ectx)
                            if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end
                            if type(ectx.form.config_digiline_channel) == "string" then
                                ectx.form.config_digiline_channel = ectx.form.config_digiline_channel:trim()
                                core.get_meta(ectx.pos):set_string("channel", ectx.form.config_digiline_channel)
                                return true
                            end
                        end,
                    },
                    gui.Button {
                        w = 1.5, max_w = 1.5, h = 0.7, max_h = 0.7,
                        label = S("Confirm"),
                        on_event = function(eplayer, ectx)
                            if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end
                            if type(ectx.form.config_digiline_channel) == "string" then
                                ectx.form.config_digiline_channel = ectx.form.config_digiline_channel:trim()
                                core.get_meta(ectx.pos):set_string("channel", ectx.form.config_digiline_channel)
                                return true
                            end
                        end,
                    }
                }
            }
        end

        config_displays[#config_displays + 1] = gui.HBox {
            gui.Button {
                w = 2, h = 0.5,
                label = S("Back"),
                expand = true, align_h = "right",
                on_event = function(_, ectx)
                    ectx.page_override = nil
                    return true
                end,
            },
        }

        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.ScrollableVBox {
                name = "svbox_page_config",
                min_w = 8.25, expand = true,
                unpack(config_displays),
            },
        }
    end,
    search = function(player, ctx)
        local query = ctx.search_query
        if type(query) ~= "string" or query:trim() == "" then
            return error_page(S("Invalid search query."))
        end
        local normalized_query = query:trim():lower()

        -- Get player's language so we can search in their local language
        local player_info = core.get_player_information(player:get_player_name())
        local player_lang = player_info and player_info.lang_code or nil
        if player_lang == "en" then
            player_lang = nil
        end

        local search_results_gui = {}
        search_results_gui[#search_results_gui + 1] = gui.Label {
            label = S("Search results of \"@1\"", query),
            expand = true, align_h = "left",
            style = {
                font = "bold",
                font_size = "*1.5"
            },
        }

        -- Search in albums
        local albums_matching = {}
        for album_name, album in pairs(phonograph.registered_albums) do
            local haystacks = {
                album_name,
                album.title and core.get_translated_string("en", album.title):lower() or nil,
                album.artist and core.get_translated_string("en", album.artist):lower() or nil,
                album.short_title and core.get_translated_string("en", album.short_title):lower() or nil,
                album.short_description and core.get_translated_string("en", album.short_description):lower() or nil,
                album.long_description and core.get_translated_string("en", album.long_description):lower() or nil,
            }
            if player_lang then
                haystacks[#haystacks + 1] = album.title and
                    core.get_translated_string(player_lang, album.title):lower() or nil
                haystacks[#haystacks + 1] = album.artist and
                    core.get_translated_string(player_lang, album.artist):lower() or nil
                haystacks[#haystacks + 1] = album.short_title and
                    core.get_translated_string(player_lang, album.short_title):lower() or nil
                haystacks[#haystacks + 1] = album.short_description and
                    core.get_translated_string(player_lang, album.short_description):lower() or nil
                haystacks[#haystacks + 1] = album.long_description and
                    core.get_translated_string(player_lang, album.long_description):lower() or nil
            end

            for _, haystack in ipairs(haystacks) do
                if haystack and haystack:find(normalized_query, 1, true) then
                    albums_matching[#albums_matching + 1] = album_name
                    break
                end
            end
        end
        table.sort(albums_matching)

        -- Add albums display
        search_results_gui[#search_results_gui + 1] = gui.Label {
            label = S("Albums"),
            expand = true, align_h = "left",
            style = {
                font = "bold",
                font_size = "*1.3"
            },
        }
        search_results_gui[#search_results_gui + 1] = gui.Label {
            label = S("@1 results found.", #albums_matching),
            expand = true, align_h = "left",
        }
        for _, album_name in ipairs(albums_matching) do
            local album = phonograph.registered_albums[album_name]

            search_results_gui[#search_results_gui + 1] = gui.HBox {
                gui.Image {
                    w = 1, h = 1,
                    texture_name = album.cover or "phonograph_node_temp_ok.png",
                    align_h = "left",
                },
                gui.Label {
                    w = 5, max_w = 5, h = 1, max_h = 1,
                    expand = true, align_h = "left",
                    label = table.concat({
                        album.title or S("Untitled"),
                        album.artist or S("Unknown artist"),
                    }, "\n")
                },
                gui.Button {
                    w = 1.5, h = 1,
                    label = S("Go"),
                    on_event = function(_, ectx)
                        ectx.selected_album = album_name
                        ectx.selected_song = nil
                        ectx.page_override = nil
                        return true
                    end,
                }
            }
        end

        -- Search in songs
        local songs_matching = {}
        for song_name, song in pairs(phonograph.registered_songs) do
            local haystacks = {
                song_name,
                song.title and core.get_translated_string("en", song.title):lower() or nil,
                song.artist and core.get_translated_string("en", song.artist):lower() or nil,
                song.short_title and core.get_translated_string("en", song.short_title):lower() or nil,
                song.short_description and core.get_translated_string("en", song.short_description):lower() or nil,
                song.long_description and core.get_translated_string("en", song.long_description):lower() or nil,
            }
            if player_lang then
                haystacks[#haystacks + 1] = song.title and
                    core.get_translated_string(player_lang, song.title):lower() or nil
                haystacks[#haystacks + 1] = song.artist and
                    core.get_translated_string(player_lang, song.artist):lower() or nil
                haystacks[#haystacks + 1] = song.short_title and
                    core.get_translated_string(player_lang, song.short_title):lower() or nil
                haystacks[#haystacks + 1] = song.short_description and
                    core.get_translated_string(player_lang, song.short_description):lower() or nil
                haystacks[#haystacks + 1] = song.long_description and
                    core.get_translated_string(player_lang, song.long_description):lower() or nil
            end

            for _, haystack in ipairs(haystacks) do
                if haystack and haystack:find(normalized_query, 1, true) then
                    songs_matching[#songs_matching + 1] = song_name
                    break
                end
            end
        end
        table.sort(songs_matching)

        -- Add songs display
        search_results_gui[#search_results_gui + 1] = gui.Label {
            label = S("Songs"),
            expand = true, align_h = "left",
            style = {
                font = "bold",
                font_size = "*1.3"
            },
        }
        search_results_gui[#search_results_gui + 1] = gui.Label {
            label = S("@1 results found.", #songs_matching),
            expand = true, align_h = "left",
        }
        for _, song_name in ipairs(songs_matching) do
            local song = phonograph.registered_songs[song_name]
            local album = phonograph.registered_albums[song.album]

            search_results_gui[#search_results_gui + 1] = gui.HBox {
                gui.Image {
                    w = 1, h = 1,
                    texture_name = album and album.cover or "phonograph_node_temp_ok.png",
                    align_h = "left",
                },
                gui.Label {
                    w = 5, max_w = 5, h = 1, max_h = 1,
                    expand = true, align_h = "left",
                    label = table.concat({
                        (song.title or S("Untitled")) .. " - " ..
                        (song.artist or (album and album.artist) or S("Unknown artist")),
                        S("In album: @1", album and (album.title or S("Untitled")) or S("Unknown album")),
                    }, "\n")
                },
                gui.Button {
                    w = 1.5, h = 1,
                    label = S("Go"),
                    on_event = function(_, ectx)
                        ectx.selected_album = song.album
                        ectx.selected_song = song_name
                        ectx.page_override = nil
                        return true
                    end,
                }
            }
        end

        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.ScrollableVBox {
                name = "svbox_page_search",
                min_w = 8.25, expand = true,
                unpack(search_results_gui),
            },
        }
    end,

    -- Album and Songs
    album = function(_, ctx)
        local album = phonograph.registered_albums[ctx.selected_album]
        if not album then
            return error_page(S("Album @1 not found.", ctx.selected_album))
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
            return error_page(S("Song @1 not found.", ctx.selected_song))
        end

        ctx.selected_album = song.album
        local album = phonograph.registered_albums[song.album]
        if not album then
            return error_page(S("Album @1 not found.", ctx.selected_album))
        end

        if album.album_set and not ctx.selected_album_set then
            ctx.selected_album_set = {}
            ctx.selected_album_set[album.album_set] = true
        end

        local meta = core.get_meta(ctx.pos)
        local footer = {}

        if song.multichannel_specs then
            footer[#footer + 1] = S("This song comes with @1 audio.",
                #song.multichannel_specs == 2 and S("stereo") or S("@1-channel", #song.multichannel_specs))
        end

        do
            local license = song.license or album.license
            if not license then
                license = S("No license information given.")
            elseif type(license) == "function" then
                license = license(song, album)
            end
            footer[#footer + 1] = license
        end

        footer[#footer + 1] = S("Song ID: @1", ctx.selected_song)

        local songs_downloading = phonograph.get_downloading_songs(player:get_player_name())

        return gui.VBox {
            min_h = 10, min_w = 9,
            gui.HBox {
                h = 2, max_h = 2,
                gui.VBox {
                    gui.Label {
                        max_w = 6, w = 6,
                        max_h = 0.5, h = 0.5,
                        label = song.title or S("Untitled")
                    },
                    gui.Label {
                        max_w = 6, w = 6,
                        max_h = 0.5, h = 0.5,
                        label = song.artist or album.artist or S("Unknown artist")
                    },
                    gui.Label {
                        max_w = 6, w = 6,
                        max_h = 1, h = 1,
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
                max_w = 9, w = 9,
                max_h = 4, h = 4,
                label =
                    (song.long_description or S("No descriptions given.")) .. "\n\n" .. table.concat(footer, "\n"),
            },
            gui.Hbox {
                max_w = 9,
                max_h = 1, h = 1,
                expand = true, align_v = "bottom",
                gui.Label {
                    max_w = 4, w = 4, max_h = 1, h = 1,
                    expand = true,
                    label = (#songs_downloading ~= 0) and ((#songs_downloading == 1)
                        and S("Downloading @1", phonograph.registered_songs[songs_downloading[1]].title)
                        or S("Downloading @1 songs", #songs_downloading)) or "",
                },
                phonograph.check_interact_privs(player, ctx.pos) and get_volume_widget(ctx) or gui.Nil {},
                phonograph.check_interact_privs(player, ctx.pos) and (
                    (meta:get_string("curr_song") == ctx.selected_song) and gui.Button {
                        -- is the playing song
                        w = 1.5, h = 1,
                        label = S("Stop"),
                        expand = true, align_h = "right", align_v = "bottom",
                        on_event = function(eplayer, ectx)
                            if not phonograph.check_interact_privs(eplayer, ectx.pos) then return true end

                            local emeta = core.get_meta(ectx.pos)
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

                            local emeta = core.get_meta(ectx.pos)
                            phonograph.set_song(emeta, ctx.selected_song)

                            phonograph.node_gui:update_where(function(uplayer, uctx)
                                return vector.equals(uctx.pos, ectx.pos)
                                    and uplayer:get_player_name() ~= eplayer:get_player_name()
                            end)

                            return true
                        end
                    }) or gui.Nil {},
            },
        }
    end
}

local generate_albums_list = function(_, ctx)
    local button_list = {}
    ctx.selected_album_set = ctx.selected_album_set or {}
    for _, name in pairs(phonograph.registered_display_entries_keys) do
        if name:sub(0, 12) == "__album_set:" then
            local album_set_name = name:sub(13)
            local album_set_def = phonograph.registered_album_sets[album_set_name]
            local is_selected = ctx.selected_album_set[album_set_name] == true
            local album_set_title = album_set_def.short_title or album_set_def.title or S("Untitled")
            local album_set_cover = (album_set_def.cover or "phonograph_node_temp_ok.png") ..
                (is_selected
                    and "^(phonograph_dropdown_overlay.png^[opacity:200^[resize:" .. album_set_def.cover_size .. "x" ..
                    album_set_def.cover_size .. "^[transformR180)"
                    or "^(phonograph_dropdown_overlay.png^[opacity:200^[resize:" .. album_set_def.cover_size .. "x" ..
                    album_set_def.cover_size .. ")")
            local album_set_title_colorize = ""
            local album_set_buttons = nil

            if is_selected then
                album_set_buttons = {}
                for _, album_name in ipairs(album_set_def.album_list) do
                    local def = phonograph.registered_albums[album_name]
                    local title = def.short_title or def.title or S("Untitled")
                    if ctx.selected_album == album_name then
                        title = core.get_color_escape_sequence("yellow") .. title
                        album_set_title_colorize = "yellow"
                    elseif ctx.curr_album == album_name then
                        title = core.get_color_escape_sequence("orange") .. title
                        if album_set_title_colorize ~= "yellow" then
                            album_set_title_colorize = "orange"
                        end
                    end
                    album_set_buttons[#album_set_buttons + 1] = gui.HBox {
                        gui.Image {
                            w = 1, h = 1,
                            texture_name = def.cover or "phonograph_node_temp_ok.png",
                            align_h = "left",
                        },
                        gui.Button {
                            w = 3.75,
                            label = title,
                            on_event = function(_, ectx)
                                ectx.selected_album = album_name
                                ectx.selected_song = nil
                                ectx.page_override = nil
                                return true
                            end,
                        },
                    }
                end
            else
                local curr_song_def = phonograph.registered_songs[ctx.curr_song]
                if curr_song_def and curr_song_def.album and
                    phonograph.registered_albums[curr_song_def.album] and
                    phonograph.registered_albums[curr_song_def.album].album_set == album_set_name then
                    album_set_title_colorize = "orange"
                end
            end

            button_list[#button_list + 1] = gui.HBox {
                gui.Image {
                    w = 1, h = 1,
                    texture_name = album_set_cover,
                    align_h = "left",
                },
                gui.Button {
                    w = 4,
                    label = (album_set_title_colorize
                        and core.get_color_escape_sequence(album_set_title_colorize) or "") .. album_set_title,
                    on_event = function(_, ectx)
                        ectx.selected_album_set[album_set_name] = not ectx.selected_album_set[album_set_name] or nil
                        return true
                    end,
                },
            }

            if album_set_buttons then
                button_list[#button_list + 1] = gui.HBox {
                    gui.Box { w = 0.05, h = 0.05, color = "grey" },
                    gui.VBox(album_set_buttons),
                }
            end
        else
            local def = phonograph.registered_albums[name]
            local title = def.short_title or def.title or S("Untitled")
            if ctx.selected_album == name then
                title = core.get_color_escape_sequence("yellow") .. title
            elseif ctx.curr_album == name then
                title = core.get_color_escape_sequence("orange") .. title
            end
            button_list[#button_list + 1] = gui.HBox {
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
                        ectx.page_override = nil
                        return true
                    end,
                },
            }
        end
    end
    button_list.name = "svb_album_list"
    button_list.w = 5.3
    button_list.h = 8.5
    return gui.ScrollableVBox(button_list)
end

local generate_songs_list = function(_, ctx)
    local button_list = {}
    for _, name in ipairs(phonograph.songs_in_album[ctx.selected_album] or {}) do
        local def = phonograph.registered_songs[name]
        local title = def.short_title or def.title or S("Untitled")
        if ctx.selected_song == name then
            title = core.get_color_escape_sequence("yellow") .. title
        elseif ctx.curr_song == name then
            title = core.get_color_escape_sequence("orange") .. title
        end
        button_list[#button_list + 1] = gui.Button {
            w = 4, h = 1,
            label = title,
            on_event = function(_, ectx)
                ectx.selected_song = name
                ectx.page_override = nil
                return true
            end,
        }
    end
    button_list.name = "svb_songs_list"
    button_list.w = 4.5
    button_list.h = 8.5
    return gui.ScrollableVBox(button_list)
end

phonograph.node_gui = flow.make_gui(function(player, ctx)
    logger:assert(ctx.pos, "`ctx` without `pos` passed into phonograph.node_gui")

    local node = core.get_node(ctx.pos)
    local controller_type = core.get_item_group(node.name, "phonograph_controller")
    if controller_type == 0 then
        return gui.VBox {
            min_h = 9, min_w = 6,
            gui.Image {
                w = 3, h = 3,
                texture_name = "phonograph_node_temp_error.png",
                expand = true, align_h = "center", align_v = "center",
            },
            gui.Label {
                label = S("ERROR: @1", S("The node at @1 is not a phonograph.", core.pos_to_string(ctx.pos))),
                expand = true, align_h = "center", align_v = "center",
            },
            gui.ButtonExit {
                label = S("Exit")
            },
        }
    end


    local meta = core.get_meta(ctx.pos)
    ctx.curr_song = meta:get_string("curr_song")
    ctx.curr_album = (phonograph.registered_songs[ctx.curr_song] or {}).album or ""
    if not (ctx.selected_album or ctx.selected_song) then
        local meta_curr_song = ctx.curr_song
        if meta_curr_song ~= "" then
            ctx.selected_song = meta_curr_song
        end
    end

    local tab_func = get_page_content.none
    if get_page_content[ctx.page_override] then
        tab_func = get_page_content[ctx.page_override]
    elseif ctx.selected_song then
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
            phonograph.check_interact_privs(player, ctx.pos) and gui.Button {
                w = 1.5, h = 0.5,
                label = S("Config"),
                on_event = function(_, ectx)
                    ectx.page_override = "config"
                    return true
                end,
            } or gui.Nil {},
            teacher_exists and gui.ButtonExit {
                label = "?",
                w = 0.5, h = 0.5,
                on_event = function(e_player)
                    core.after(0, function(name)
                        if core.get_player_by_name(name) then
                            teacher.simple_show(e_player, "phonograph:tutorial_phonograph")
                        end
                    end, e_player:get_player_name())
                end,
            } or gui.Nil {},
            gui.ButtonExit {
                w = 0.5, h = 0.5,
                label = "x",
            },
        },
        gui.Box { w = 0.05, h = 0.05, color = "grey" },

        gui.HBox {
            gui.VBox {
                gui.HBox {
                    expand = true, align_v = "top",
                    generate_albums_list(player, ctx),
                    generate_songs_list(player, ctx),
                },
                gui.HBox {
                    gui.Field {
                        name = "search_field",
                        w = 9, h = 1, max_h = 1,
                        expand = true, align_h = "left",
                        on_key_enter = function(_, ectx)
                            local query = ectx.form.search_field or ""
                            if query:trim() == "" then
                                if ectx.page_override == "search" then
                                    ectx.page_override = nil
                                    return true
                                end
                                return false
                            end
                            ectx.search_query = query
                            ectx.page_override = "search"
                            return true
                        end,
                    },
                    gui.Button {
                        w = 2, max_w = 2, h = 1, max_h = 1,
                        label = S("Search"),
                        on_event = function(_, ectx)
                            local query = ectx.form.search_field or ""
                            if query:trim() == "" then
                                if ectx.page_override == "search" then
                                    ectx.page_override = nil
                                    return true
                                end
                                return false
                            end
                            ectx.search_query = query
                            ectx.page_override = "search"
                            return true
                        end,
                    },
                },
            },
            tab_content
        }
    }
end)
