import '../audio/quality_info.dart';

class Track {
  const Track({
    required this.path,
    required this.title,
    this.artist = 'Unknown artist',
    this.album = 'Unknown album',
    this.genre = '',
    this.codec = '',
    this.year,
    this.trackNo,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.durationMs = 0,
    this.rgTrackGain,
    this.rgAlbumGain,
    this.rgTrackPeak,
    this.rgAlbumPeak,
    this.coverPath,
    this.modifiedMs = 0,
    this.sizeBytes = 0,
  });

  final String path, title, artist, album, genre, codec;
  final int? year, trackNo, sampleRate, bitDepth, channels;
  final int durationMs;
  final double? rgTrackGain, rgAlbumGain, rgTrackPeak, rgAlbumPeak;
  final String? coverPath;
  final int modifiedMs, sizeBytes;

  SourceQuality get quality => SourceQuality(
      codec: codec, sampleRateHz: sampleRate, bitDepth: bitDepth);

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'codec': codec,
        'year': year,
        'trackNo': trackNo,
        'sr': sampleRate,
        'bd': bitDepth,
        'ch': channels,
        'dur': durationMs,
        'rgtg': rgTrackGain,
        'rgag': rgAlbumGain,
        'rgtp': rgTrackPeak,
        'rgap': rgAlbumPeak,
        'cover': coverPath,
        'mod': modifiedMs,
        'size': sizeBytes,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        path: j['path'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? 'Unknown artist',
        album: j['album'] as String? ?? 'Unknown album',
        genre: j['genre'] as String? ?? '',
        codec: j['codec'] as String? ?? '',
        year: j['year'] as int?,
        trackNo: j['trackNo'] as int?,
        sampleRate: j['sr'] as int?,
        bitDepth: j['bd'] as int?,
        channels: j['ch'] as int?,
        durationMs: j['dur'] as int? ?? 0,
        rgTrackGain: (j['rgtg'] as num?)?.toDouble(),
        rgAlbumGain: (j['rgag'] as num?)?.toDouble(),
        rgTrackPeak: (j['rgtp'] as num?)?.toDouble(),
        rgAlbumPeak: (j['rgap'] as num?)?.toDouble(),
        coverPath: j['cover'] as String?,
        modifiedMs: j['mod'] as int? ?? 0,
        sizeBytes: j['size'] as int? ?? 0,
      );
}

class Album {
  Album(this.name, this.artist, this.tracks);
  final String name, artist;
  final List<Track> tracks;
  String? get cover =>
      tracks.map((t) => t.coverPath).whereType<String>().firstOrNull;
  int? get year => tracks.map((t) => t.year).whereType<int>().firstOrNull;
}

class Artist {
  Artist(this.name, this.tracks);
  final String name;
  final List<Track> tracks;
  int get albumCount => tracks.map((t) => t.album).toSet().length;
  String? get cover =>
      tracks.map((t) => t.coverPath).whereType<String>().firstOrNull;
}
