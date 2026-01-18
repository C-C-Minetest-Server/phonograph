# Phonograph Developer Documentation

## Album registeration

```lua
-- Modified from phonograph_album_white code
local album = phonograph.register_album("phonograph_album_white:album_white", {
    short_title = "World of White",
    title = "Wonders of Randoms: World of White",
    short_description = "Relaxing noises for testing purpose",
    long_description = "Oh, so relaxing! A bug-free world starts from a test case.",
    cover = "phonograph_album_white_cover.png",
    artist = "Dave Null",
})
```

## Song registeration

```lua
-- Recommended: Send songs dynamically and use the album object
-- This attaches the song onto that album
album:register_song("white", {
    title = S("Pure White Noise"),
    short_description = S("20 seconds of white noise"),
    long_description = "ffmpeg -f lavfi -i anoisesrc=c=white:r=48000 -t 20",
    artist = "anoise",
    spec = { -- a SimpleSoundSpec
        -- do not include a name
        filepath = table.concat({
            minetest.get_modpath("phonograph_album_white"),
            "phonographs",
            "phonograph_album_white_song_white.ogg" -- with .ogg
        }, DIR_DELIM),
        gain = 0.3
    }
})
```

```lua
-- NOT Recommended: not sending songs dynamically
album:register_song("white", { -- Final ID will be phonograph_album_white:album_white:white
    title = "Pure White Noise",
    short_description = "20 seconds of white noise",
    long_description = "ffmpeg -f lavfi -i anoisesrc=c=white:r=48000 -t 20",
    artist = "anoise",
    spec = { -- a SimpleSoundSpec
        name = "phonograph_album_white_song_white", -- Without .ogg
        gain = 0.3
    }
})

-- NOT Recommended: register directly
-- Make sure to attach it onto an album, or it will not be accessible
phonograph.register_song("phonograph_album_white:album_white:white", {
    title = "Pure White Noise",
    short_description = "20 seconds of white noise",
    long_description = "ffmpeg -f lavfi -i anoisesrc=c=white:r=48000 -t 20",
    artist = "anoise",
    album = "phonograph_album_white:album_white",
    spec = { -- a SimpleSoundSpec
        name = "phonograph_album_white_song_white", -- Without .ogg
        gain = 0.3
    }
})
```

## Preparation of soundtracks

According to the [Minetest API Documentation](https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sounds), only single-channel OGG Vorbis files are supported. You should prepend around 3 seconds of silence before the song starts to avoid timing problems when switching or repeating the track.

This script can convert any soundtrack (stereo or mono) into a mono OGG meeting the above recommendations:

```bash
INPUT="YOUR-INPUT.wav"
OUTPUT="OUTPUT.ogg"
ffmpeg -f lavfi -t 3 -i "anullsrc=channel_layout=mono:sample_rate=$(ffmpeg -i "$INPUT" 2>&1 | grep -oP '([0-9]+) Hz' | awk '{print $1}')" -i "$INPUT" -ac 1 -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1[outa]" -map "[outa]" -map_metadata 1 "$OUTPUT"
```
