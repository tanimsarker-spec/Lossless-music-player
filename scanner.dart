import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'tag_reader.dart';
import 'track.dart';

/// APE, WMA and WavPack are intentionally excluded: neither ExoPlayer nor
/// AVPlayer can decode them, and no suitable bundled decoder is wired in.
const audioExts = {
  '.flac', '.wav', '.aiff', '.aif', '.m4a', '.mp3', '.aac', '.ogg', '.opus',
};

const _coverNames = [
  'cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 'front.jpg',
  'front.png', 'album.jpg', 'albumart.jpg',
];

class ScanResult {
  ScanResult(this.tracks, this.failed, this.unreachable);
  final List<Track> tracks;
  final int failed;
  final List<String> unreachable;
}

int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Runs in a background isolate so the UI never blocks.
Future<ScanResult> scanFolders({
  required List<String> roots,
  required Map<String, Track> existing,
  required String artDir,
}) =>
    Isolate.run(() => scanSync(roots, existing, artDir));

ScanResult scanSync(
    List<String> roots, Map<String, Track> existing, String artDir) {
  final out = <String, Track>{};
  final unreachable = <String>[];
  var failed = 0;

  void walk(Directory d) {
    List<FileSystemEntity> kids;
    try {
      kids = d.listSync(followLinks: false);
    } catch (_) {
      unreachable.add(d.path);
      return;
    }
    for (final e in kids) {
      if (e is Directory) {
        walk(e);
      } else if (e is File &&
          audioExts.contains(p.extension(e.path).toLowerCase())) {
        if (out.containsKey(e.path)) continue;
        FileStat st;
        try {
          st = e.statSync();
        } catch (_) {
          failed++;
          continue;
        }
        final old = existing[e.path];
        final mod = st.modified.millisecondsSinceEpoch;
        if (old != null && old.modifiedMs == mod && old.sizeBytes == st.size) {
          out[e.path] = old;
          continue;
        }
        final t = readTrack(e.path, mod, st.size, artDir);
        if (t == null) {
          failed++;
        } else {
          out[e.path] = t;
        }
      }
    }
  }

  for (final r in roots) {
    final d = Directory(r);
    if (!d.existsSync()) {
      unreachable.add(r);
      continue;
    }
    walk(d);
  }
  return ScanResult(out.values.toList(), failed, unreachable);
}

/// Never throws: a corrupt tag still yields a playable, filename-titled track.
Track? readTrack(String path, int mod, int size, String artDir) {
  final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
  RawTags raw = RawTags();
  try {
    raw = switch (ext) {
      'flac' => readFlac(path, wantArt: true),
      'wav' => readWav(path),
      _ => readGeneric(path),
    };
  } catch (_) {
    // keep empty tags
  }
  String? cover;
  try {
    final pic = raw.picture;
    if (pic != null && pic.isNotEmpty) {
      final png = (raw.pictureMime ?? '').contains('png');
      final f = File(p.join(
          artDir, '${_fnv(path).toRadixString(16)}.${png ? 'png' : 'jpg'}'));
      if (!f.existsSync()) f.writeAsBytesSync(pic);
      cover = f.path;
    } else {
      final dir = p.dirname(path);
      for (final n in _coverNames) {
        final f = File(p.join(dir, n));
        if (f.existsSync()) {
          cover = f.path;
          break;
        }
      }
    }
  } catch (_) {}
  String clean(String? s, String fallback) =>
      (s == null || s.trim().isEmpty) ? fallback : s.trim();
  return Track(
    path: path,
    title: clean(raw.title, p.basenameWithoutExtension(path)),
    artist: clean(raw.artist, 'Unknown artist'),
    album: clean(raw.album, 'Unknown album'),
    genre: raw.genre?.trim() ?? '',
    codec: ext,
    year: raw.year,
    trackNo: raw.trackNo,
    sampleRate: raw.sampleRate,
    bitDepth: raw.bitDepth,
    channels: raw.channels,
    durationMs: raw.durationMs ?? 0,
    rgTrackGain: raw.rgTrackGain,
    rgAlbumGain: raw.rgAlbumGain,
    rgTrackPeak: raw.rgTrackPeak,
    rgAlbumPeak: raw.rgAlbumPeak,
    coverPath: cover,
    modifiedMs: mod,
    sizeBytes: size,
  );
}
