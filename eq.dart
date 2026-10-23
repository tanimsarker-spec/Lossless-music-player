import 'dart:math' as math;

enum BandType { peaking, lowShelf, highShelf }

const isoFreqs = <double>[
  31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
];

class EqBand {
  const EqBand({
    required this.freq,
    this.gainDb = 0,
    this.q = 1.41,
    this.type = BandType.peaking,
    this.enabled = true,
  });
  final double freq, gainDb, q;
  final BandType type;
  final bool enabled;

  EqBand copyWith({
    double? freq,
    double? gainDb,
    double? q,
    BandType? type,
    bool? enabled,
  }) =>
      EqBand(
        freq: freq ?? this.freq,
        gainDb: gainDb ?? this.gainDb,
        q: q ?? this.q,
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() =>
      {'f': freq, 'g': gainDb, 'q': q, 't': type.index, 'e': enabled};

  factory EqBand.fromJson(Map<String, dynamic> j) => EqBand(
        freq: (j['f'] as num).toDouble(),
        gainDb: (j['g'] as num).toDouble(),
        q: (j['q'] as num).toDouble(),
        type: BandType.values[(j['t'] as int).clamp(0, 2)],
        enabled: j['e'] as bool? ?? true,
      );
}

class EqState {
  const EqState({this.enabled = true, this.preampDb = 0, required this.bands});

  final bool enabled;
  final double preampDb;
  final List<EqBand> bands;

  factory EqState.flat() =>
      EqState(bands: [for (final f in isoFreqs) EqBand(freq: f)]);

  factory EqState.fromGains(List<double> g,
      {bool enabled = true, double preampDb = 0}) {
    return EqState(
      enabled: enabled,
      preampDb: preampDb,
      bands: [
        for (var i = 0; i < isoFreqs.length; i++)
          EqBand(freq: isoFreqs[i], gainDb: i < g.length ? g[i] : 0),
      ],
    );
  }

  EqState copyWith({bool? enabled, double? preampDb, List<EqBand>? bands}) =>
      EqState(
        enabled: enabled ?? this.enabled,
        preampDb: preampDb ?? this.preampDb,
        bands: bands ?? this.bands,
      );

  EqState withBand(int i, EqBand b) {
    final n = [...bands];
    n[i] = b;
    return copyWith(bands: n);
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'preamp': preampDb,
        'bands': bands.map((b) => b.toJson()).toList(),
      };

  factory EqState.fromJson(Map<String, dynamic> j) => EqState(
        enabled: j['enabled'] as bool? ?? true,
        preampDb: (j['preamp'] as num?)?.toDouble() ?? 0,
        bands: (j['bands'] as List)
            .map((e) => EqBand.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Normalised biquad (a0 = 1), RBJ Audio-EQ-Cookbook.
class Biquad {
  const Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);
  final double b0, b1, b2, a1, a2;

  double magnitudeDb(double f, double fs) {
    final w = 2 * math.pi * f / fs;
    final c1 = math.cos(w), s1 = math.sin(w);
    final c2 = math.cos(2 * w), s2 = math.sin(2 * w);
    final nr = b0 + b1 * c1 + b2 * c2, ni = -(b1 * s1 + b2 * s2);
    final dr = 1 + a1 * c1 + a2 * c2, di = -(a1 * s1 + a2 * s2);
    final num = nr * nr + ni * ni, den = dr * dr + di * di;
    return 10 * math.log(num / den) / math.ln10;
  }
}

Biquad designBand(EqBand b, double fs) {
  final f = b.freq.clamp(10.0, fs * 0.45).toDouble();
  final q = b.q.clamp(0.1, 20.0).toDouble();
  final a = math.pow(10, b.gainDb / 40).toDouble();
  final w0 = 2 * math.pi * f / fs;
  final cs = math.cos(w0), sn = math.sin(w0);
  double b0, b1, b2, a0, a1, a2;
  switch (b.type) {
    case BandType.peaking:
      final alP = sn / (2 * q);
      b0 = 1 + alP * a;
      b1 = -2 * cs;
      b2 = 1 - alP * a;
      a0 = 1 + alP / a;
      a1 = -2 * cs;
      a2 = 1 - alP / a;
    case BandType.lowShelf:
      final alL = sn / 2 * math.sqrt(2); // shelf slope S = 1
      final tL = 2 * math.sqrt(a) * alL;
      b0 = a * ((a + 1) - (a - 1) * cs + tL);
      b1 = 2 * a * ((a - 1) - (a + 1) * cs);
      b2 = a * ((a + 1) - (a - 1) * cs - tL);
      a0 = (a + 1) + (a - 1) * cs + tL;
      a1 = -2 * ((a - 1) + (a + 1) * cs);
      a2 = (a + 1) + (a - 1) * cs - tL;
    case BandType.highShelf:
      final alH = sn / 2 * math.sqrt(2);
      final tH = 2 * math.sqrt(a) * alH;
      b0 = a * ((a + 1) + (a - 1) * cs + tH);
      b1 = -2 * a * ((a - 1) + (a + 1) * cs);
      b2 = a * ((a + 1) + (a - 1) * cs - tH);
      a0 = (a + 1) - (a - 1) * cs + tH;
      a1 = 2 * ((a - 1) - (a + 1) * cs);
      a2 = (a + 1) - (a - 1) * cs - tH;
  }
  return Biquad(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
}

/// Combined response of all enabled bands (preamp excluded).
double responseDb(EqState s, double f, [double fs = 48000]) {
  var sum = 0.0;
  for (final b in s.bands) {
    if (!b.enabled || b.gainDb == 0) continue;
    sum += designBand(b, fs).magnitudeDb(f, fs);
  }
  return sum;
}

const eqPresets = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Rock': [4, 3, 2, -1, -2, -1, 2, 3, 4, 4],
  'Metal': [4, 3, 0, -2, -1, 0, 3, 4, 5, 4],
  'Classical': [3, 2, 1, 1, -1, -1, 0, 1, 2, 3],
  'Electronic': [5, 4, 1, 0, -2, 2, 1, 1, 4, 5],
  'Hip-hop': [5, 4, 2, 3, -1, -1, 2, -1, 2, 3],
  'Acoustic': [3, 3, 2, 1, 1, 1, 2, 2, 3, 2],
  'Vocal clarity': [-2, -2, -1, 1, 3, 4, 3, 2, 0, -1],
  'Bass boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
};
