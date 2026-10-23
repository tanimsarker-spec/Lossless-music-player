import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../library/actions.dart';
import '../library/track.dart';
import 'shell.dart';

void playFrom(List<Track> list, int i) =>
    App.handler.playTracks(list, index: i);

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenPlayer});
  final VoidCallback onOpenPlayer;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.library,
      builder: (ctx, _) {
        final lib = App.library;
        if (lib.tracks.isEmpty) return _Empty(scanning: lib.scanning);
        final q = _q.toLowerCase();
        final songs = lib.search(_q);
        final albums = q.isEmpty
            ? lib.albums
            : lib.albums
                .where((a) =>
                    a.name.toLowerCase().contains(q) ||
                    a.artist.toLowerCase().contains(q))
                .toList();
        final artists = q.isEmpty
            ? lib.artists
            : lib.artists.where((a) => a.name.toLowerCase().contains(q)).toList();
        return DefaultTabController(
          length: 6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search ${lib.tracks.length} tracks',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: LColors.border)),
                  ),
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: LColors.border,
                tabs: [
                  Tab(text: 'Songs'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Artists'),
                  Tab(text: 'Favorites'),
                  Tab(text: 'Recent'),
                  Tab(text: 'Most played'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TrackList(songs, emptyText: 'No matches'),
                    _AlbumGrid(albums),
                    _ArtistList(artists),
                    _TrackList(lib.favoriteTracks,
                        emptyText: 'Long-press a song and choose Favorite'),
                    _TrackList(lib.recentTracks,
                        emptyText: 'Songs you play appear here'),
                    _TrackList(lib.mostPlayed,
                        emptyText: 'Play counts start after 10 seconds of a song'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scanning});
  final bool scanning;
  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Scanning your music…'),
      ]));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_outlined, size: 48, color: LColors.silverDim),
            const SizedBox(height: 16),
            const Text('Your library is empty', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              Platform.isIOS
                  ? 'Import files, or copy music into the LOSSLESS folder using the Files app.'
                  : 'Choose a folder to scan, or import individual files.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: LColors.silverDim, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (!Platform.isIOS)
              FilledButton.icon(
                onPressed: () async => toast(context, await LibraryActions.addFolder()),
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose music folder'),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async => toast(context, await LibraryActions.importFiles()),
              icon: const Icon(Icons.add),
              label: const Text('Import files'),
            ),
            if (App.library.status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(App.library.status,
                  style: const TextStyle(color: LColors.silverDim, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList(this.tracks, {required this.emptyText});
  final List<Track> tracks;
  final String emptyText;
  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
          child: Text(emptyText, style: const TextStyle(color: LColors.silverDim)));
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemExtent: 64,
      itemBuilder: (_, i) => TrackTile(
        track: tracks[i],
        onTap: () => playFrom(tracks, i),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final q = track.quality;
    return ListTile(
      leading: Cover(path: track.coverPath, size: 44, radius: 6),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} · ${q.detail}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: LColors.silverDim),
      ),
      trailing: App.library.isFav(track)
          ? const Icon(Icons.favorite, size: 16, color: LColors.electric)
          : null,
      onTap: onTap,
      onLongPress: () => showTrackActions(context, track),
    );
  }
}

void showTrackActions(BuildContext context, Track t) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.artist),
          ),
          ListTile(
            leading: const Icon(Icons.queue_play_next),
            title: const Text('Play next'),
            onTap: () {
              Navigator.pop(ctx);
              App.handler.playNext(t);
              toast(context, 'Will play next');
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Add to queue'),
            onTap: () {
              Navigator.pop(ctx);
              App.handler.addToQueue(t);
              toast(context, 'Added to queue');
            },
          ),
          ListTile(
            leading: Icon(App.library.isFav(t) ? Icons.favorite : Icons.favorite_border),
            title: Text(App.library.isFav(t) ? 'Remove favorite' : 'Favorite'),
            onTap: () {
              Navigator.pop(ctx);
              App.library.toggleFav(t);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            onTap: () {
              Navigator.pop(ctx);
              showTrackDetails(context, t);
            },
          ),
        ],
      ),
    ),
  );
}

void showTrackDetails(BuildContext context, Track t) {
  String v(Object? o) => o == null || '$o'.isEmpty ? 'Not in file' : '$o';
  final rows = <(String, String)>[
    ('Title', t.title),
    ('Artist', t.artist),
    ('Album', t.album),
    ('Genre', v(t.genre)),
    ('Year', v(t.year)),
    ('Track #', v(t.trackNo)),
    ('Format', t.codec.toUpperCase()),
    ('Source quality', t.quality.label),
    ('Bit depth', t.bitDepth == null ? 'Not reported by this format reader' : '${t.bitDepth}-bit'),
    ('Sample rate', t.sampleRate == null ? 'Not reported' : '${t.sampleRate} Hz'),
    ('Channels', v(t.channels)),
    ('Duration', fmtDuration(t.duration)),
    ('ReplayGain track', t.rgTrackGain == null ? 'None' : '${t.rgTrackGain} dB'),
    ('ReplayGain album', t.rgAlbumGain == null ? 'None' : '${t.rgAlbumGain} dB'),
    ('File', t.path),
  ];
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Track details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${r.$1}: ',
                      style: const TextStyle(color: LColors.silverDim, fontSize: 12)),
                  TextSpan(text: r.$2, style: const TextStyle(fontSize: 13)),
                ])),
              ),
            const SizedBox(height: 8),
            const Text('Tag editing is not implemented yet.',
                style: TextStyle(fontSize: 12, color: LColors.silverDim)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid(this.albums);
  final List<Album> albums;
  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const Center(child: Text('No matches'));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => TrackCollectionPage(title: a.name, subtitle: a.artist, tracks: a.tracks, cover: a.cover))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: LayoutBuilder(
                      builder: (_, c) => Cover(path: a.cover, size: c.maxWidth))),
              const SizedBox(height: 6),
              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(a.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: LColors.silverDim)),
            ],
          ),
        );
      },
    );
  }
}

class _ArtistList extends StatelessWidget {
  const _ArtistList(this.artists);
  final List<Artist> artists;
  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: artists.length,
        itemExtent: 64,
        itemBuilder: (_, i) {
          final a = artists[i];
          return ListTile(
            leading: Cover(path: a.cover, size: 44, radius: 22),
            title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${a.albumCount} album(s) · ${a.tracks.length} tracks',
                style: const TextStyle(fontSize: 12, color: LColors.silverDim)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => TrackCollectionPage(
                        title: a.name, subtitle: 'Artist', tracks: a.tracks, cover: a.cover))),
          );
        },
      );
}

class TrackCollectionPage extends StatelessWidget {
  const TrackCollectionPage(
      {super.key, required this.title, required this.subtitle, required this.tracks, this.cover});
  final String title, subtitle;
  final List<Track> tracks;
  final String? cover;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Cover(path: cover, size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle, style: const TextStyle(color: LColors.silverDim)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        FilledButton.icon(
                          onPressed: () {
                            playFrom(tracks, 0);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            await App.handler.playTracks(tracks, autoplay: false);
                            await App.handler
                                .setShuffleMode(AudioServiceShuffleMode.all);
                            await App.handler.play();
                            nav.pop();
                          },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Shuffle'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemExtent: 64,
              itemBuilder: (_, i) => TrackTile(
                track: tracks[i],
                onTap: () {
                  playFrom(tracks, i);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
