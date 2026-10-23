import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class LrcLine {
  const LrcLine(this.time, this.text);
  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics.synced(this.lines) : plain = null;
  const Lyrics.plain(this.plain) : lines = const [];
  final List<LrcLine> lines;
  final String? plain;
  bool get synced => lines.isNotEmpty;
}

final _ts = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offset = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

/// Parses LRC. Text with no timestamps becomes plain lyrics. Never invents
/// timing.
Lyrics? parseLyrics(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return null;
  final off = int.tryParse(_offset.firstMatch(text)?.group(1) ?? '') ?? 0;
  final out = <LrcLine>[];
  for (final line in text.split('\n')) {
    final ms = _ts.allMatches(line).toList();
    if (ms.isEmpty) continue;
    final body = line.replaceAll(_ts, '').trim();
    for (final m in ms) {
      final frac = m.group(3);
      var fms = 0;
      if (frac != null) {
        fms = frac.length == 1
            ? int.parse(frac) * 100
            : frac.length == 2
                ? int.parse(frac) * 10
                : int.parse(frac);
      }
      final total = int.parse(m.group(1)!) * 60000 +
          int.parse(m.group(2)!) * 1000 +
          fms -
          off; // positive offset = show earlier (LRC convention)
      out.add(LrcLine(Duration(milliseconds: total < 0 ? 0 : total), body));
    }
  }
  if (out.isNotEmpty) {
    out.sort((a, b) => a.time.compareTo(b.time));
    return Lyrics.synced(out);
  }
  final plain = text
      .split('\n')
      .where((l) => !RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(l.trim()))
      .join('\n')
      .trim();
  return plain.isEmpty ? null : Lyrics.plain(plain);
}

/// Index of the last line at or before [pos], or -1.
int lyricIndexAt(List<LrcLine> lines, Duration pos) {
  var lo = 0, hi = lines.length - 1, res = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= pos) {
      res = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return res;
}

class LyricsLoad {
  const LyricsLoad({this.lyrics, this.error});
  final Lyrics? lyrics;
  final String? error; // null lyrics + null error == none found
}

/// Looks for `<track>.lrc`, then `<track>.txt` beside the audio file.
Future<LyricsLoad> loadSidecarLyrics(String audioPath) async {
  final base = p.withoutExtension(audioPath);
  try {
    for (final ext in const ['.lrc', '.txt']) {
      final f = File('$base$ext');
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        return LyricsLoad(
            lyrics: parseLyrics(utf8.decode(bytes, allowMalformed: true)));
      }
    }
    return const LyricsLoad();
  } catch (e) {
    return LyricsLoad(error: 'Could not read lyrics file: $e');
  }
}
