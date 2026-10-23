import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../audio/route_monitor.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../library/track.dart';
import 'lyrics_view.dart';
import 'queue_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _lyrics = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final h = App.handler;
    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (_, snap) {
        final item = snap.data;
        final t = h.trackFor(item?.id);
        if (item == null || t == null) {
          return const Center(
              child: Text('Nothing playing', style: TextStyle(color: LColors.silverDim)));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _lyrics
                      ? LyricsView(key: ValueKey('l${t.path}'), track: t)
                      : Cover(key: ValueKey(t.path), path: t.coverPath, radius: 14),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${t.artist} — ${t.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LColors.silverDim)),
            const SizedBox(height: 10),
            _QualityRow(track: t, expanded: _expanded, onToggle: () => setState(() => _expanded = !_expanded)),
            const SizedBox(height: 6),
            const _SeekBar(),
            const _Controls(),
            const SizedBox(height: 4),
            _ExtraRow(
              track: t,
              lyricsOn: _lyrics,
              onLyrics: () => setState(() => _lyrics = !_lyrics),
            ),
            const _AbRow(),
          ],
        );
      },
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.track, required this.expanded, required this.onToggle});
  final Track track;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final q = track.quality;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: LColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([App.routes, App.handler.rgInfo, App.settings, App.handler.dsp]),
          builder: (_, __) {
            final route = App.routes.likelyActive;
            final bt = route != null && isBluetoothDevice(route);
            final rg = App.handler.rgInfo.value;
            final eq = App.settings.eq;
            final dsp = App.handler.dsp;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.graphic_eq, size: 16, color: LColors.electric),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Source: ${q.label}  ·  ${q.detail}',
                          style: const TextStyle(fontSize: 12.5))),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Output: ${route?.name ?? 'not reported'}'
                  '${bt ? ' (Bluetooth, lossy)' : ''}',
                  style: const TextStyle(fontSize: 12, color: LColors.silverDim),
                ),
                if (expanded) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Output sample rate and bit depth are decided by the OS and the audio route; '
                    'this app cannot read them, so none is shown.',
                    style: const TextStyle(fontSize: 12, color: LColors.silverDim, height: 1.4),
                  ),
                  if (bt)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Bluetooth re-encodes audio with a lossy codec; the original lossless stream is not delivered.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE0B040), height: 1.4),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'EQ: ${!dsp.available ? 'not applied on this platform' : (eq.enabled ? 'on' : 'bypassed')}'
                    '  ·  ReplayGain: ${rg == null ? 'off / no tags' : '${rg.appliedDb.toStringAsFixed(1)} dB (${rg.source})${rg.cappedAtUnity ? ', boost capped' : ''}'}',
                    style: const TextStyle(fontSize: 12, color: LColors.silverDim),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final p = App.handler.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = p.duration ?? Duration.zero;
        final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
        return Column(children: [
          Slider(
            min: 0,
            max: max,
            value: value,
            onChangeStart: (v) => setState(() => _drag = v),
            onChanged: (v) => setState(() => _drag = v),
            onChangeEnd: (v) {
              App.handler.seek(Duration(milliseconds: v.toInt()));
              setState(() => _drag = null);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmtDuration(Duration(milliseconds: value.toInt())),
                    style: const TextStyle(fontSize: 12, color: LColors.silverDim)),
                Text(fmtDuration(dur),
                    style: const TextStyle(fontSize: 12, color: LColors.silverDim)),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();
  @override
  Widget build(BuildContext context) {
    final h = App.handler;
    return StreamBuilder<PlaybackState>(
      stream: h.playbackState,
      builder: (_, snap) {
        final s = snap.data;
        final shuffle = s?.shuffleMode == AudioServiceShuffleMode.all;
        final rep = s?.repeatMode ?? AudioServiceRepeatMode.none;
        final playing = s?.playing ?? false;
        final err = s?.processingState == AudioProcessingState.error;
        return Column(children: [
          if (err)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(s?.errorMessage ?? 'Playback error',
                  style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
                onPressed: () => h.setShuffleMode(
                    shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
                icon: Icon(Icons.shuffle, color: shuffle ? LColors.electric : null),
              ),
              IconButton(
                tooltip: 'Previous',
                iconSize: 36,
                onPressed: h.skipToPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton.filled(
                tooltip: playing ? 'Pause' : 'Play',
                iconSize: 38,
                style: IconButton.styleFrom(
                    backgroundColor: LColors.silver, foregroundColor: Colors.black),
                onPressed: playing ? h.pause : h.play,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Next',
                iconSize: 36,
                onPressed: h.skipToNext,
                icon: const Icon(Icons.skip_next),
              ),
              IconButton(
                tooltip: 'Repeat: ${rep.name}',
                onPressed: () => h.setRepeatMode(switch (rep) {
                  AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
                  AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
                  _ => AudioServiceRepeatMode.none,
                }),
                icon: Icon(
                  rep == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                  color: rep == AudioServiceRepeatMode.none ? null : LColors.electric,
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.track, required this.lyricsOn, required this.onLyrics});
  final Track track;
  final bool lyricsOn;
  final VoidCallback onLyrics;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.library,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Favorite',
            onPressed: () => App.library.toggleFav(track),
            icon: Icon(App.library.isFav(track) ? Icons.favorite : Icons.favorite_border,
                color: App.library.isFav(track) ? LColors.electric : null),
          ),
          IconButton(
            tooltip: lyricsOn ? 'Show artwork' : 'Show lyrics',
            onPressed: onLyrics,
            icon: Icon(Icons.lyrics_outlined, color: lyricsOn ? LColors.electric : null),
          ),
          IconButton(
            tooltip: 'Queue',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const QueueScreen())),
            icon: const Icon(Icons.queue_music),
          ),
          PopupMenuButton<double>(
            tooltip: 'Playback speed',
            icon: const Icon(Icons.speed),
            onSelected: App.handler.setSpeed,
            itemBuilder: (_) => [
              for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0])
                PopupMenuItem(value: s, child: Text('${s}x')),
            ],
          ),
          IconButton(
            tooltip: 'Sleep timer',
            onPressed: () => _sleepSheet(context),
            icon: ListenableBuilder(
              listenable: App.handler.sleep,
              builder: (_, __) => Icon(Icons.bedtime_outlined,
                  color: App.handler.sleep.active ? LColors.electric : null),
            ),
          ),
        ],
      ),
    );
  }

  void _sleepSheet(BuildContext context) {
    final s = App.handler.sleep;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Sleep timer'),
                subtitle: Text(s.active
                    ? 'Stops in ${fmtDuration(s.remaining ?? Duration.zero)} with a fade-out'
                    : 'Fades out over the last ${App.settings.sleepFadeSec.round()} s'),
              ),
              for (final m in const [15, 30, 45, 60, 90])
                ListTile(
                  title: Text('$m minutes'),
                  onTap: () {
                    s.start(Duration(minutes: m),
                        fade: Duration(seconds: App.settings.sleepFadeSec.round()));
                    Navigator.pop(ctx);
                  },
                ),
              if (s.active)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel timer'),
                  onTap: () {
                    s.cancel();
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbRow extends StatelessWidget {
  const _AbRow();
  @override
  Widget build(BuildContext context) {
    final h = App.handler;
    return ListenableBuilder(
      listenable: Listenable.merge([h.abA, h.abB]),
      builder: (_, __) {
        final a = h.abA.value, b = h.abB.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('A–B repeat', style: TextStyle(color: LColors.silverDim, fontSize: 12)),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: h.setLoopA,
              child: Text(a == null ? 'Set A' : 'A ${fmtDuration(a)}'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: a == null ? null : h.setLoopB,
              child: Text(b == null ? 'Set B' : 'B ${fmtDuration(b)}'),
            ),
            if (a != null)
              IconButton(
                  tooltip: 'Clear A–B loop',
                  onPressed: h.clearLoop,
                  icon: const Icon(Icons.close, size: 18)),
          ],
        );
      },
    );
  }
}
