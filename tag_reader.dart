import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../audio/replaygain.dart';

/// Raw values pulled from a file header. Anything unknown stays null.
class RawTags {
  String? title, artist, album, genre;
  int? year, trackNo, sampleRate, bitDepth, channels, durationMs;
  double? rgTrackGain, rgAlbumGain, rgTrackPeak, rgAlbumPeak;
  Uint8List? picture;
  String? pictureMime;

  void setVorbis(String key, String v) {
    switch (key) {
      case 'TITLE':
        title = v;
      case 'ARTIST':
        artist = v;
      case 'ALBUM':
        album = v;
      case 'GENRE':
        genre = v;
      case 'DATE':
      case 'YEAR':
        year = int.tryParse(v.length >= 4 ? v.substring(0, 4) : v);
      case 'TRACKNUMBER':
        trackNo = int.tryParse(v.split('/').first.trim());
      case 'REPLAYGAIN_TRACK_GAIN':
        rgTrackGain = parseGainDb(v);
      case 'REPLAYGAIN_ALBUM_GAIN':
        rgAlbumGain = parseGainDb(v);
      case 'REPLAYGAIN_TRACK_PEAK':
        rgTrackPeak = double.tryParse(v.trim());
      case 'REPLAYGAIN_ALBUM_PEAK':
        rgAlbumPeak = double.tryParse(v.trim());
    }
  }
}

void _parseVorbis(Uint8List d, RawTags t) {
  final bd = ByteData.sublistView(d);
  var o = 0;
  final vl = bd.getUint32(o, Endian.little);
  o += 4 + vl;
  if (o + 4 > d.length) return;
  final n = bd.getUint32(o, Endian.little);
  o += 4;
  for (var i = 0; i < n; i++) {
    if (o + 4 > d.length) break;
    final l = bd.getUint32(o, Endian.little);
    o += 4;
    if (o + l > d.length) break;
    final s = utf8.decode(d.sublist(o, o + l), allowMalformed: true);
    o += l;
    final eq = s.indexOf('=');
    if (eq <= 0) continue;
    t.setVorbis(s.substring(0, eq).toUpperCase(), s.substring(eq + 1));
  }
}

void _parsePicture(Uint8List d, RawTags t) {
  final bd = ByteData.sublistView(d);
  var o = 4; // picture type
  final mimeLen = bd.getUint32(o);
  o += 4;
  t.pictureMime = ascii.decode(d.sublist(o, o + mimeLen), allowInvalid: true);
  o += mimeLen;
  final descLen = bd.getUint32(o);
  o += 4 + descLen + 16; // desc + width/height/depth/colors
  final dataLen = bd.getUint32(o);
  o += 4;
  if (o + dataLen <= d.length) t.picture = d.sublist(o, o + dataLen);
}

/// Reads FLAC STREAMINFO (true sample rate / bit depth / duration), Vorbis
/// comments (tags + ReplayGain) and optionally the first embedded picture.
RawTags readFlac(String path, {bool wantArt = false}) {
  final raf = File(path).openSync();
  try {
    var magic = raf.readSync(4);
    if (magic.length == 4 && String.fromCharCodes(magic.sublist(0, 3)) == 'ID3') {
      raf.setPositionSync(0);
      final h = raf.readSync(10);
      final size = (h[6] << 21) | (h[7] << 14) | (h[8] << 7) | h[9];
      raf.setPositionSync(10 + size);
      magic = raf.readSync(4);
    }
    if (magic.length < 4 || String.fromCharCodes(magic) != 'fLaC') {
      throw const FormatException('Not a FLAC file');
    }
    final t = RawTags();
    var last = false;
    while (!last) {
      final h = raf.readSync(4);
      if (h.length < 4) break;
      last = (h[0] & 0x80) != 0;
      final type = h[0] & 0x7f;
      final len = (h[1] << 16) | (h[2] << 8) | h[3];
      if (type == 0 && len >= 34) {
        final d = raf.readSync(len);
        final sr = (d[10] << 12) | (d[11] << 4) | (d[12] >> 4);
        t.sampleRate = sr;
        t.channels = ((d[12] >> 1) & 7) + 1;
        t.bitDepth = (((d[12] & 1) << 4) | (d[13] >> 4)) + 1;
        final total = ((d[13] & 0xF) << 32) |
            (d[14] << 24) |
            (d[15] << 16) |
            (d[16] << 8) |
            d[17];
        if (sr > 0 && total > 0) t.durationMs = (total * 1000 / sr).round();
      } else if (type == 4) {
        _parseVorbis(raf.readSync(len), t);
      } else if (type == 6 &&
          wantArt &&
          t.picture == null &&
          len <= 16 * 1024 * 1024) {
        _parsePicture(raf.readSync(len), t);
      } else {
        raf.setPositionSync(raf.positionSync() + len);
      }
    }
    return t;
  } finally {
    raf.closeSync();
  }
}

/// Reads the RIFF `fmt ` and `data` chunks for exact format and duration.
RawTags readWav(String path) {
  final raf = File(path).openSync();
  try {
    final head = raf.readSync(12);
    if (head.length < 12 ||
        String.fromCharCodes(head.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(head.sublist(8, 12)) != 'WAVE') {
      throw const FormatException('Not a WAV file');
    }
    final t = RawTags();
    int? dataSize, byteRate;
    while (t.sampleRate == null || dataSize == null) {
      final h = raf.readSync(8);
      if (h.length < 8) break;
      final id = String.fromCharCodes(h.sublist(0, 4));
      final size = ByteData.sublistView(h).getUint32(4, Endian.little);
      if (id == 'fmt ' && size >= 16) {
        final d = ByteData.sublistView(raf.readSync(size));
        t.channels = d.getUint16(2, Endian.little);
        t.sampleRate = d.getUint32(4, Endian.little);
        byteRate = d.getUint32(8, Endian.little);
        t.bitDepth = d.getUint16(14, Endian.little);
        if (size.isOdd) raf.setPositionSync(raf.positionSync() + 1);
      } else {
        if (id == 'data') dataSize = size;
        raf.setPositionSync(raf.positionSync() + size + (size.isOdd ? 1 : 0));
      }
    }
    if (dataSize != null && byteRate != null && byteRate > 0) {
      t.durationMs = (dataSize * 1000 / byteRate).round();
    }
    return t;
  } finally {
    raf.closeSync();
  }
}

/// MP3 / M4A / Ogg / Opus via audio_metadata_reader. Accessed dynamically so
/// a field that is missing in a given package version degrades to null
/// instead of breaking the scan.
RawTags readGeneric(String path) {
  final t = RawTags();
  final dynamic m = readMetadata(File(path), getImage: true);
  T? g<T>(T? Function() f) {
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  t.title = g<String>(() => m.title as String?);
  t.artist = g<String>(() => m.artist as String?);
  t.album = g<String>(() => m.album as String?);
  final genres = g<List>(() => m.genres as List?);
  if (genres != null && genres.isNotEmpty) t.genre = genres.first.toString();
  final y = g<dynamic>(() => m.year);
  t.year = y is int ? y : (y is DateTime ? y.year : null);
  t.trackNo = g<int>(() => m.trackNumber as int?);
  t.sampleRate = g<int>(() => m.samplerate as int?);
  final dur = g<Duration>(() => m.duration as Duration?);
  if (dur != null) t.durationMs = dur.inMilliseconds;
  final pics = g<List>(() => m.pictures as List?);
  if (pics != null && pics.isNotEmpty) {
    t.picture = g<Uint8List>(() => pics.first.bytes as Uint8List?);
    t.pictureMime = g<String>(() => pics.first.mimetype as String?);
  }
  return t;
}
