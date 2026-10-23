import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/audio/replaygain.dart';
import 'package:lossless/audio/sleep_timer.dart';

void main() {
  test('parseGainDb handles units and signs', () {
    expect(parseGainDb('-6.50 dB'), -6.5);
    expect(parseGainDb('+3.2dB'), 3.2);
    expect(parseGainDb(null), isNull);
    expect(parseGainDb('abc'), isNull);
  });

  test('off mode or missing tag applies nothing', () {
    expect(computeReplayGain(mode: RgMode.off, trackGain: -5), isNull);
    expect(computeReplayGain(mode: RgMode.track), isNull);
  });

  test('negative gain becomes attenuation', () {
    final r = computeReplayGain(mode: RgMode.track, trackGain: -6.0206)!;
    expect(r.volume, closeTo(0.5, 0.001));
    expect(r.cappedAtUnity, isFalse);
  });

  test('positive gain is capped at unity and flagged', () {
    final r = computeReplayGain(mode: RgMode.track, trackGain: 4)!;
    expect(r.volume, 1.0);
    expect(r.cappedAtUnity, isTrue);
  });

  test('album mode prefers album gain, falls back to track', () {
    final a = computeReplayGain(
        mode: RgMode.album, trackGain: -3, albumGain: -9)!;
    expect(a.source, 'album');
    expect(a.appliedDb, -9);
    final b = computeReplayGain(mode: RgMode.album, trackGain: -3)!;
    expect(b.source, 'track');
  });

  test('preamp shifts gain', () {
    final r = computeReplayGain(mode: RgMode.track, trackGain: -4, preampDb: -2)!;
    expect(r.appliedDb, -6);
  });

  test('sleep fade ramps over the final seconds only', () {
    const fade = Duration(seconds: 20);
    expect(fadeFactor(const Duration(minutes: 5), fade), 1);
    expect(fadeFactor(const Duration(seconds: 10), fade), closeTo(0.5, 1e-9));
    expect(fadeFactor(Duration.zero, fade), 0);
    expect(fadeFactor(const Duration(seconds: 5), Duration.zero), 1);
  });
}
