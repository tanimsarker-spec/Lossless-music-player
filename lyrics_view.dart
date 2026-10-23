import 'package:flutter/material.dart';
import '../app.dart';
import '../core/theme.dart';
import '../library/track.dart';
import '../lyrics/lrc.dart';

/// Shows sidecar lyrics (.lrc synced, or .txt plain). Distinguishes
/// loading, not found and read errors. Never guesses lyrics.
class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.track});
  final Track track;
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late Future<LyricsLoad> _f = loadSidecarLyrics(widget.track.path);
  final _scroll = ScrollController();
  static const _h = 44.0;
  int _last = -2;

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (old.track.path != widget.track.path) {
      _f = loadSidecarLyrics(widget.track.path);
      _last = -2;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LyricsLoad>(
      future: _f,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        if (r.error != null) return _msg(r.error!, Icons.error_outline);
        final l = r.lyrics;
        if (l == null) {
          return _msg(
              'No lyrics file found.\nPlace "${widget.track.title}.lrc" (synced) or .txt next to the audio file with the same name.',
              Icons.lyrics_outlined);
        }
        if (!l.synced) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(l.plain!, style: const TextStyle(fontSize: 16, height: 1.6)),
          );
        }
        return StreamBuilder<Duration>(
          stream: App.handler.player.positionStream,
          builder: (_, ps) {
            final idx = lyricIndexAt(l.lines, ps.data ?? Duration.zero);
            if (idx != _last && _scroll.hasClients) {
              _last = idx;
              final target = (idx * _h - _scroll.position.viewportDimension / 2 + _h)
                  .clamp(0.0, _scroll.position.maxScrollExtent);
              _scroll.animateTo(target,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            }
            return ListView.builder(
              controller: _scroll,
              itemExtent: _h,
              itemCount: l.lines.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => App.handler.seek(l.lines[i].time),
                child: Center(
                  child: Text(
                    l.lines[i].text.isEmpty ? '·' : l.lines[i].text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: i == idx ? 18 : 15,
                      fontWeight: i == idx ? FontWeight.w600 : FontWeight.w400,
                      color: i == idx ? Colors.white : LColors.silverDim,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _msg(String m, IconData icon) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: LColors.silverDim, size: 36),
            const SizedBox(height: 12),
            Text(m,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LColors.silverDim, height: 1.4)),
          ]),
        ),
      );
}
