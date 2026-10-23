import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/audio/eq.dart';

void main() {
  test('flat EQ has 0 dB response everywhere', () {
    final s = EqState.flat();
    for (final f in [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
      expect(responseDb(s, f), closeTo(0, 1e-9));
    }
  });

  test('peaking band reaches its gain at centre frequency', () {
    const b = EqBand(freq: 1000, gainDb: 6, q: 1);
    expect(designBand(b, 48000).magnitudeDb(1000, 48000), closeTo(6, 0.01));
  });

  test('peaking band leaves distant frequencies almost untouched', () {
    const b = EqBand(freq: 1000, gainDb: 6, q: 2);
    expect(designBand(b, 48000).magnitudeDb(40, 48000).abs(), lessThan(0.2));
  });

  test('negative gain cuts', () {
    const b = EqBand(freq: 250, gainDb: -8, q: 1.4);
    expect(designBand(b, 44100).magnitudeDb(250, 44100), closeTo(-8, 0.01));
  });

  test('low shelf boosts lows, not highs', () {
    const b = EqBand(freq: 150, gainDb: 6, type: BandType.lowShelf);
    final z = designBand(b, 48000);
    expect(z.magnitudeDb(20, 48000), closeTo(6, 0.3));
    expect(z.magnitudeDb(10000, 48000).abs(), lessThan(0.3));
  });

  test('high shelf boosts highs, not lows', () {
    const b = EqBand(freq: 6000, gainDb: 5, type: BandType.highShelf);
    final z = designBand(b, 48000);
    expect(z.magnitudeDb(18000, 48000), closeTo(5, 0.5));
    expect(z.magnitudeDb(50, 48000).abs(), lessThan(0.3));
  });

  test('disabled band is ignored', () {
    final s = EqState.flat().withBand(
        5, const EqBand(freq: 1000, gainDb: 9, enabled: false));
    expect(responseDb(s, 1000), 0);
  });

  test('state JSON round trip', () {
    final s = EqState.fromGains(eqPresets['Rock']!, preampDb: -3);
    final r = EqState.fromJson(s.toJson());
    expect(r.preampDb, -3);
    expect(r.bands[0].gainDb, 4);
    expect(r.bands.length, 10);
  });

  test('every preset fits the 10 ISO bands', () {
    for (final e in eqPresets.entries) {
      expect(e.value.length, 10, reason: e.key);
    }
  });
}
