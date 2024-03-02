# Phonograph API Documentation

## Album registeration

```lua
-- Modified from phonograph_album_white code
local album = phonograph.register_album("phonograph_album_white:album_white", {
    title = "World of White",
    short_description = "Relaxing noises for testing purpose",
    long_description = "Oh, so relaxing! A bug-free world starts from a test case.",
    cover = "phonograph_album_white_cover.png",
    artist = "Dave Null",
})
```

## Song registeration

```lua
-- Recommended: register via the album object
-- This attaches the song onto that album
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
