import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/library/tag_reader.dart';

Uint8List _flac({int sr = 96000, int ch = 2, int bps = 24, int total = 960000}) {
  final b = BytesBuilder();
  b.add(ascii.encode('fLaC'));
  // STREAMINFO header: not last, type 0, len 34
  b.add([0x00, 0, 0, 34]);
  final si = Uint8List(34);
  si[10] = sr >> 12;
  si[11] = (sr >> 4) & 0xFF;
  si[12] = ((sr & 0xF) << 4) | ((ch - 1) << 1) | ((bps - 1) >> 4);
  si[13] = (((bps - 1) & 0xF) << 4) | ((total >> 32) & 0xF);
  si[14] = (total >> 24) & 0xFF;
  si[15] = (total >> 16) & 0xFF;
  si[16] = (total >> 8) & 0xFF;
  si[17] = total & 0xFF;
  b.add(si);
  // VORBIS_COMMENT, last block
  final vc = BytesBuilder();
  void le32(int v) => vc.add(
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  final vendor = utf8.encode('test');
  le32(vendor.length);
  vc.add(vendor);
  final comments = [
    'TITLE=Song',
    'ARTIST=Band',
    'ALBUM=Record',
    'TRACKNUMBER=3/12',
    'DATE=2021-05-01',
    'REPLAYGAIN_TRACK_GAIN=-6.50 dB',
    'REPLAYGAIN_TRACK_PEAK=0.98',
  ];
  le32(comments.length);
  for (final c in comments) {
    final e = utf8.encode(c);
    le32(e.length);
    vc.add(e);
  }
  final v = vc.toBytes();
  b.add([0x84, (v.length >> 16) & 0xFF, (v.length >> 8) & 0xFF, v.length & 0xFF]);
  b.add(v);
  return b.toBytes();
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('lossless_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('FLAC STREAMINFO gives true sample rate, bit depth and duration', () {
    final f = File('${dir.path}/a.flac')..writeAsBytesSync(_flac());
    final t = readFlac(f.path);
    expect(t.sampleRate, 96000);
    expect(t.bitDepth, 24);
    expect(t.channels, 2);
    expect(t.durationMs, 10000);
  });

  test('FLAC 16-bit 44.1k', () {
    final f = File('${dir.path}/b.flac')
      ..writeAsBytesSync(_flac(sr: 44100, bps: 16, total: 44100 * 3));
    final t = readFlac(f.path);
    expect(t.sampleRate, 44100);
    expect(t.bitDepth, 16);
    expect(t.durationMs, 3000);
  });

  test('Vorbis comments and ReplayGain are parsed', () {
    final f = File('${dir.path}/c.flac')..writeAsBytesSync(_flac());
    final t = readFlac(f.path);
    expect(t.title, 'Song');
    expect(t.artist, 'Band');
    expect(t.album, 'Record');
    expect(t.trackNo, 3);
    expect(t.year, 2021);
    expect(t.rgTrackGain, -6.5);
    expect(t.rgTrackPeak, 0.98);
  });

  test('non-FLAC data throws instead of returning junk', () {
    final f = File('${dir.path}/d.flac')..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
    expect(() => readFlac(f.path), throwsFormatException);
  });

  test('WAV fmt/data chunks', () {
    final b = BytesBuilder();
    final fmt = ByteData(16)
      ..setUint16(0, 1, Endian.little)
      ..setUint16(2, 2, Endian.little)
      ..setUint32(4, 48000, Endian.little)
      ..setUint32(8, 48000 * 2 * 3, Endian.little)
      ..setUint16(12, 6, Endian.little)
      ..setUint16(14, 24, Endian.little);
    b.add(ascii.encode('RIFF'));
    b.add([0, 0, 0, 0]);
    b.add(ascii.encode('WAVE'));
    b.add(ascii.encode('fmt '));
    b.add([16, 0, 0, 0]);
    b.add(fmt.buffer.asUint8List());
    b.add(ascii.encode('data'));
    final dataSize = 48000 * 2 * 3 * 2; // 2 seconds
    b.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
    final f = File('${dir.path}/e.wav')..writeAsBytesSync(b.toBytes());
    final t = readWav(f.path);
    expect(t.sampleRate, 48000);
    expect(t.bitDepth, 24);
    expect(t.durationMs, 2000);
  });
}
