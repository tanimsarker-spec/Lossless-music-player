# Capabilities, limits and unfinished work

## Platform matrix
| Feature | Android | Android TV | iOS | Windows | Linux |
|---|---|---|---|---|---|
| Playback, gapless queue, seek, speed | Yes | Yes | Yes | Yes | Yes |
| Background + lock screen + media buttons | Yes | Yes | Yes | No (not wired) | No (not wired) |
| Interruptions / unplug-pause | Yes | Yes | Yes | No | No |
| Library scan of chosen folders | Yes* | Yes* | Import / Files app only | Yes | Yes |
| FLAC/WAV exact specs, tags, artwork | Yes | Yes | Yes | Yes | Yes |
| Equalizer applied to audio | Yes (system EQ, fixed HW bands) | Yes | **No** | **No** | **No** |
| ReplayGain (attenuation) | Yes | Yes | Yes | Yes | Yes |
| Output device list | Yes | Yes | Yes | No | No |
| Sleep timer, A–B repeat, speed | Yes | Yes | Yes | Yes | Yes |
| Lyrics (sidecar LRC/TXT) | Yes | Yes | Yes | Yes | Yes |

\* Android scoped storage: only folders the OS lets the app read. Use "Import files" otherwise.

## Format notes
- FLAC, WAV, MP3, AAC/M4A (AAC, ALAC on iOS), Ogg Vorbis, Opus: decoded by ExoPlayer / AVPlayer / libmpv.
- ALAC on Android and AIFF on Android are not reliably supported by ExoPlayer.
- APE, WMA, WavPack: not supported (excluded from scans).
- Bit depth / sample rate are exact for FLAC and WAV only. For other formats they are shown as unknown rather than guessed.

## Audio path honesty
- The app never claims bit-perfect output. Android resamples to the device mixer rate unless the route allows otherwise; the OS does not report this to the app.
- Bluetooth is always lossy. Codec and output rate are not read; the UI says so.
- ExoPlayer/AVPlayer decode to PCM internally; this app cannot guarantee a float/24-bit internal path.
- Preamp is folded into Android equalizer band gains; large boosts can clip and there is no limiter yet.

## Not implemented (do not rely on these)
Bass enhancement, crossfeed, stereo widening, balance, loudness compensation, limiter,
crossfade, fade-in/out between tracks, per-device/per-track/per-album DSP profiles,
EQ/preset import-export, backup/restore, playlists (create/edit/import/export), smart playlists,
tag editing, manual artwork editing, ReplayGain scanner, embedded-lyrics reading, online lyrics,
audio visualizer (needs a PCM tap), waveform scrubber, genre/composer/year/folder browsing,
configurable home screen, gestures, widgets, searchable settings, USB DAC exclusive mode,
Bluetooth codec display, headphone volume warnings, Windows/Linux media keys, app icon,
integration tests for background audio and interruptions (must be run on real devices),
a SQLite library store for very large collections.
