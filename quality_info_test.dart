import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/audio/quality_info.dart';

void main() {
  test('CD-quality FLAC is never labeled hi-res', () {
    const q = SourceQuality(codec: 'flac', sampleRateHz: 44100, bitDepth: 16);
    expect(q.tier, SourceTier.cdLossless);
    expect(q.label, isNot(contains('Hi-Res')));
  });

  test('24-bit/96k FLAC is hi-res', () {
    const q = SourceQuality(codec: 'flac', sampleRateHz: 96000, bitDepth: 24);
    expect(q.tier, SourceTier.hiRes);
  });

  test('MP3 is lossy regardless of sample rate', () {
    const q = SourceQuality(codec: 'mp3', sampleRateHz: 96000, bitDepth: 24);
    expect(q.tier, SourceTier.lossy);
  });

  test('lossless with unknown specs is not guessed', () {
    expect(const SourceQuality(codec: 'flac').tier, SourceTier.unknown);
  });

  test('Bluetooth warns about lossy transport', () {
    const o = OutputPath(routeName: 'Buds', isBluetooth: true, btCodec: 'AAC');
    expect(o.warning, contains('lossy'));
  });

  test('detail string formats rates', () {
    const q = SourceQuality(codec: 'flac', sampleRateHz: 88200, bitDepth: 24);
    expect(q.detail, 'FLAC · 24-bit · 88.2 kHz');
  });
}
