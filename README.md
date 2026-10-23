# LOSSLESS — by TanimSarker

Local-first audiophile music player. Flutter, one codebase:
Android, Android TV, iOS, Windows, Linux.

> Status: **v0.2 (stages 1–3)**. Written and unit-tested logic; **not yet compiled or run on
> devices by the author of this scaffold**. Expect a first-build fix-up pass and test on real
> hardware (background audio, interruptions, Bluetooth) before trusting it.

## What works (by design)
- Playback: gapless queue, seek, speed, shuffle, repeat, A–B repeat, sleep timer with fade-out,
  queue persistence and resume.
- Background/lock screen/notification/headset buttons (Android, iOS). Pause on unplug, call and
  navigation interruptions.
- Library: folder scan in a background isolate, incremental rescans, FLAC/WAV header parsing
  (true bit depth, sample rate, duration), tags and artwork, albums/artists, search,
  favorites, recent, most played, duplicate finder, play next / add to queue / drag-reorder queue.
- Honest quality labels (source only); Bluetooth lossy warning; output device list.
- Equalizer: 10-band parametric model (freq/gain/Q/type), presets, curve view, undo/reset,
  bypass. **Applied to audio on Android only** (system equalizer). Other platforms save settings but
  say they are not applied.
- ReplayGain (track/album, preamp, clip prevention) from tags, attenuation only.
- Lyrics: sidecar `.lrc` (synced) and `.txt`.
- AMOLED / dark / light themes, TanimSarker brand header.

See `docs/CAPABILITIES.md` for the full matrix, limits and the unfinished list.

## Build locally
```bash
flutter create . --project-name lossless --org app.lossless \
  --platforms=android,ios,windows,linux
python3 tool/patch_platforms.py      # Android manifest + iOS Info.plist
flutter pub get
flutter analyze
flutter test
flutter run
```
Outputs:
```bash
flutter build apk --release --split-per-abi      # Android (also installs on Android TV)
flutter build appbundle --release                # Play Store
flutter build ios --release --no-codesign        # then sign in Xcode
flutter build windows --release
flutter build linux --release                    # needs libmpv-dev, libgtk-3-dev
```

## GitHub
Push this folder. `.github/workflows/build.yml` runs analyze + tests, then builds Android
(APK+AAB), iOS (unsigned IPA), Windows (zip), Linux (tar.gz). Push a tag like `v0.2.0` to publish a
Release. Android release builds use debug signing until you add your own keystore; iOS needs your
Apple signing for TestFlight/App Store.

## Android TV
The same APK runs on Android TV (leanback launcher flag is added by the patch script). The UI is
touch-first; D-pad navigation works through standard focus but has not been tuned for TV.
tvOS is not supported by Flutter.

## Project layout
```
lib/audio      handler, EQ math, DSP bridge, ReplayGain, sleep timer, route monitor
lib/library    track model, FLAC/WAV/tag readers, scanner (isolate), store
lib/lyrics     LRC parser + sidecar loader
lib/features   screens (library, now playing, queue, EQ, output, settings, lyrics)
lib/core       theme, branding, settings, logging, widgets
test/          unit tests (FLAC/WAV parsing, LRC, EQ filters, ReplayGain, models)
tool/          platform patch script
```
