# Phonograph Digilines API Documentation

## Configure Digiline channel

Use the "config" tab in a phonograph or a phonograph controller to set the digiline channel. If not set, the phonograph will not react to any digiline messages.

## Interactions with the phonograph

Send commands (usualy in table format) to the phonograph's channel. The phonograph will return another message through the same channel.

If an error is returned, it will be in the following format:

```lua
{
    ok = false,
    error = ERROR_MESSAGE,
}
```

Check individual actions for `ERROR_MESSAGE` references.

## Commands

If a command is not recognized, a `msg_command_no_match` error will be raised.

### Set a song (`play`)

To play the song `phonograph_album_1f616emo:album_1f616emo:garden` on a phonograph with channel `phonograph`:

```lua
-- By a string
digiline_send("phonograph", "phonograph_album_1f616emo:album_1f616emo:garden")

-- By table
digiline_send("phonograph", {
    command = "play",
    song = "phonograph_album_1f616emo:album_1f616emo:garden", -- Technical ID, not the display name
})
```

Return value:

```lua
{
    ok = true,
    command_responce = "play",
}
```

Possible error values:

* `msg_song_type_error`: The type of the value of `msg.song` is not a string.
  * If the table format is not used, type errors will be silent.
* `msg_song_not_found`: No song of the given ID is found.
  * Make sure you are supplying the technical ID of the song (found at the bottom of a song's tab), not the display name.

### Stop songs playing (`stop`)

To stop any songs playing on a phonograph with channel `phonograph`:

```lua
-- By a string
digiline_send("phonograph", "")

-- By table
digiline_send("phonograph", {
    command = "stop",
})
```

Note that using an empty string in command = play does not stop any audio.

Return value:

```lua
{
    ok = true,
    command_responce = "stop",
}
```

### Set volume of the phonograph (`set_volume`)

To set the volume of a phonograph with channel `phonograph`:

```lua
digiline_send("phonograph", {
    command = "set_volume",
    volume = 50, -- Volume between 1 and 100
})
```

Return value:

```lua
{
    ok = true,
    command_responce = "set_volume",
}
```

Possible error values:

* `msg_volume_type_error`: The type of the value of `msg.volume` is not a number.
* `msg_volume_out_of_range`: The volume is not between 1 and 100 (inclusive).

### Get current song and volume (`get`)

To retrieve the currently playing song and volume from a phonograph with channel `phonograph`:

```lua
digiline_send("phonograph", {
    command = "get",
})
```

Return value:

```lua
{
    ok = true,
    command_responce = "get",
    curr_song = "phonograph_album_1f616emo:album_1f616emo:garden", -- Empty string if nothing is playing
    volume = 50,
}
```
