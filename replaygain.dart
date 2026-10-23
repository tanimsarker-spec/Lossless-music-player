import 'dart:math' as math;

enum RgMode { off, track, album }

class RgResult {
  const RgResult({
    required this.volume,
    required this.appliedDb,
    required this.cappedAtUnity,
    required this.source,
  });
  final double volume; // linear, 0..1
  final double appliedDb;
  /// True when the file asked for a boost that player volume cannot deliver.
  final bool cappedAtUnity;
  final String source; // 'track' or 'album'
}

double? parseGainDb(String? s) {
  if (s == null) return null;
  final m = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!);
}

/// ReplayGain via output attenuation only. Positive gains are capped at
/// 0 dB because boosting a decoded stream without a limiter risks clipping.
RgResult? computeReplayGain({
  required RgMode mode,
  double? trackGain,
  double? albumGain,
  double? trackPeak,
  double? albumPeak,
  double preampDb = 0,
  bool preventClipping = true,
}) {
  if (mode == RgMode.off) return null;
  double? gain, peak;
  String src;
  if (mode == RgMode.album && albumGain != null) {
    gain = albumGain;
    peak = albumPeak;
    src = 'album';
  } else {
    gain = trackGain;
    peak = trackPeak;
    src = 'track';
  }
  if (gain == null) return null;
  var db = gain + preampDb;
  if (preventClipping && peak != null && peak > 0) {
    final maxDb = -20 * math.log(peak) / math.ln10;
    if (db > maxDb) db = maxDb;
  }
  var capped = false;
  if (db > 0) {
    db = 0;
    capped = true;
  }
  return RgResult(
    volume: math.pow(10, db / 20).toDouble(),
    appliedDb: db,
    cappedAtUnity: capped,
    source: src,
  );
}
