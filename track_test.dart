import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/audio/quality_info.dart';
import 'package:lossless/library/track.dart';

void main() {
  test('Track JSON round trip keeps quality fields', () {
    const t = Track(
      path: '/m/a.flac',
      title: 'A',
      codec: 'flac',
      sampleRate: 96000,
      bitDepth: 24,
      durationMs: 1234,
      rgTrackGain: -5.5,
    );
    final r = Track.fromJson(t.toJson());
    expect(r.path, t.path);
    expect(r.quality.tier, SourceTier.hiRes);
    expect(r.rgTrackGain, -5.5);
    expect(r.durationMs, 1234);
  });

  test('Track.fromJson tolerates missing fields', () {
    final r = Track.fromJson({'path': '/x.mp3'});
    expect(r.artist, 'Unknown artist');
    expect(r.quality.tier, SourceTier.unknown);
  });
}
