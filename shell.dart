import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../core/branding.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'eq_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'output_screen.dart';
import 'settings_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 6),
              child: BrandHeader(),
            ),
            Expanded(
              child: IndexedStack(
                index: _i,
                children: [
                  LibraryScreen(onOpenPlayer: () => setState(() => _i = 1)),
                  const NowPlayingScreen(),
                  const EqScreen(),
                  const OutputScreen(),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_i != 1) _MiniPlayer(onTap: () => setState(() => _i = 1)),
          NavigationBar(
            height: 64,
            selectedIndex: _i,
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.album_outlined), label: 'Playing'),
              NavigationDestination(icon: Icon(Icons.equalizer), label: 'EQ'),
              NavigationDestination(icon: Icon(Icons.headphones_outlined), label: 'Output'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = App.handler;
    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (_, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        return Material(
          color: LColors.charcoal,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: LColors.border))),
              child: Row(
                children: [
                  Cover(path: item.artUri?.toFilePath(), size: 40, radius: 6),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: LColors.silverDim)),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: h.player.playingStream,
                    builder: (_, s) {
                      final playing = s.data ?? false;
                      return IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        iconSize: 30,
                        onPressed: playing ? h.pause : h.play,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: h.skipToNext,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Used by other screens for consistent snack messages.
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));
