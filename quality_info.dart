/// Honest quality labeling. This describes the SOURCE FILE only.
/// It never claims anything about the actual output path.
enum SourceTier { lossy, cdLossless, hiRes, unknown }

class SourceQuality {
  final String codec; // e.g. 'flac', 'mp3'
  final int? sampleRateHz;
  final int? bitDepth;

  const SourceQuality({required this.codec, this.sampleRateHz, this.bitDepth});

  static const _lossless = {'flac', 'alac', 'wav', 'aiff', 'aif', 'ape', 'wv'};

  bool get isLossless => _lossless.contains(codec.toLowerCase());

  SourceTier get tier {
    if (codec.isEmpty) return SourceTier.unknown;
    if (!isLossless) return SourceTier.lossy;
    final sr = sampleRateHz, bd = bitDepth;
    if (sr == null || bd == null) return SourceTier.unknown;
    // Beyond 16-bit or beyond 48 kHz counts as high-resolution.
    if (bd > 16 || sr > 48000) return SourceTier.hiRes;
    return SourceTier.cdLossless;
  }

  String get label => switch (tier) {
        SourceTier.hiRes => 'Hi-Res source',
        SourceTier.cdLossless => 'Lossless (CD quality)',
        SourceTier.lossy => 'Lossy',
        SourceTier.unknown => 'Quality unknown',
      };

  String get detail {
    final parts = <String>[codec.toUpperCase()];
    if (bitDepth != null) parts.add('$bitDepth-bit');
    if (sampleRateHz != null) {
      final k = sampleRateHz! / 1000;
      parts.add('${k == k.roundToDouble() ? k.toInt() : k} kHz');
    }
    return parts.join(' · ');
  }
}

/// Output path info. Fields are null when the OS does not expose them
/// reliably; the UI must show "Not reported by OS" instead of guessing.
class OutputPath {
  final String routeName;
  final bool isBluetooth;
  final int? outputSampleRateHz;
  final String? btCodec;

  const OutputPath({
    required this.routeName,
    this.isBluetooth = false,
    this.outputSampleRateHz,
    this.btCodec,
  });

  String? get warning => isBluetooth
      ? 'Bluetooth re-encodes audio with a lossy codec'
          '${btCodec != null ? ' ($btCodec)' : ''}. '
          'The original lossless stream is not delivered.'
      : null;
}
