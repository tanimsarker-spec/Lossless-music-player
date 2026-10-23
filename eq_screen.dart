import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app.dart';
import '../audio/eq.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class EqScreen extends StatefulWidget {
  const EqScreen({super.key});
  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
  final List<EqState> _undo = [];

  void _push() {
    _undo.add(App.settings.eq);
    if (_undo.length > 50) _undo.removeAt(0);
  }

  void _set(EqState s) => App.settings.setEq(s);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([App.settings, App.handler.dsp]),
      builder: (context, _) {
        final s = App.settings.eq;
        final dsp = App.handler.dsp;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Equalizer', style: TextStyle(fontSize: 18))),
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: _undo.isEmpty
                        ? null
                        : () {
                            final prev = _undo.removeLast();
                            _set(prev);
                          },
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Reset to flat',
                    onPressed: () {
                      _push();
                      _set(EqState.flat().copyWith(enabled: s.enabled));
                    },
                    icon: const Icon(Icons.restart_alt),
                  ),
                  Switch(
                    value: s.enabled,
                    onChanged: (v) => _set(s.copyWith(enabled: v)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                s.enabled ? 'On' : 'Bypassed: playing the unprocessed signal',
                style: const TextStyle(fontSize: 12, color: LColors.silverDim),
              ),
            ),
            InfoCard(
              dsp.capabilityText,
              warn: !dsp.available,
              icon: dsp.available ? Icons.check_circle_outline : Icons.warning_amber,
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in eqPresets.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(e.key),
                        onPressed: () {
                          _push();
                          _set(EqState.fromGains(e.value,
                              enabled: s.enabled, preampDb: s.preampDb));
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 2.3,
                child: Container(
                  decoration: BoxDecoration(
                    color: LColors.charcoal,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LColors.border),
                  ),
                  child: CustomPaint(painter: _CurvePainter(s)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: Row(
                children: [
                  for (var i = 0; i < s.bands.length; i++)
                    Expanded(child: _BandColumn(index: i, state: s, onStart: _push, onChange: _set)),
                ],
              ),
            ),
            const SectionTitle('Preamp'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Expanded(
                  child: Slider(
                    min: -12,
                    max: 12,
                    divisions: 48,
                    value: s.preampDb.clamp(-12.0, 12.0),
                    onChangeStart: (_) => _push(),
                    onChanged: (v) => _set(s.copyWith(preampDb: v)),
                  ),
                ),
                SizedBox(
                    width: 64,
                    child: Text('${s.preampDb.toStringAsFixed(1)} dB',
                        textAlign: TextAlign.right)),
              ]),
            ),
            const InfoCard(
              'Use a negative preamp when boosting bands to avoid clipping. '
              'Balance, bass enhancement, crossfeed, stereo widening, loudness '
              'compensation and a limiter are not implemented yet.',
            ),
          ],
        );
      },
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn({
    required this.index,
    required this.state,
    required this.onStart,
    required this.onChange,
  });
  final int index;
  final EqState state;
  final VoidCallback onStart;
  final void Function(EqState) onChange;

  String _f(double f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
      : f.toStringAsFixed(f == f.roundToDouble() ? 0 : 0);

  @override
  Widget build(BuildContext context) {
    final b = state.bands[index];
    return Column(
      children: [
        Text(b.gainDb.toStringAsFixed(0),
            style: const TextStyle(fontSize: 10, color: LColors.silverDim)),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(
                min: -12,
                max: 12,
                divisions: 48,
                value: b.gainDb.clamp(-12.0, 12.0),
                semanticFormatterCallback: (v) => '${_f(b.freq)} hertz, ${v.toStringAsFixed(1)} decibels',
                onChangeStart: (_) => onStart(),
                onChanged: (v) => onChange(state.withBand(index, b.copyWith(gainDb: v))),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: () => _editBand(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_f(b.freq), style: const TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }

  void _editBand(BuildContext context) {
    onStart();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: App.settings,
        builder: (_, __) {
          final s = App.settings.eq;
          final b = s.bands[index];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Band ${index + 1} (parametric)', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  SegmentedButton<BandType>(
                    segments: const [
                      ButtonSegment(value: BandType.lowShelf, label: Text('Low shelf')),
                      ButtonSegment(value: BandType.peaking, label: Text('Peak')),
                      ButtonSegment(value: BandType.highShelf, label: Text('High shelf')),
                    ],
                    selected: {b.type},
                    onSelectionChanged: (v) =>
                        App.settings.setEq(s.withBand(index, b.copyWith(type: v.first))),
                  ),
                  const SizedBox(height: 8),
                  Text('Frequency: ${b.freq.round()} Hz'),
                  Slider(
                    min: math.log(20),
                    max: math.log(20000),
                    value: math.log(b.freq.clamp(20.0, 20000.0)),
                    onChanged: (v) => App.settings
                        .setEq(s.withBand(index, b.copyWith(freq: math.exp(v)))),
                  ),
                  Text('Gain: ${b.gainDb.toStringAsFixed(1)} dB'),
                  Slider(
                    min: -12,
                    max: 12,
                    value: b.gainDb.clamp(-12.0, 12.0),
                    onChanged: (v) =>
                        App.settings.setEq(s.withBand(index, b.copyWith(gainDb: v))),
                  ),
                  Text('Q: ${b.q.toStringAsFixed(2)}'),
                  Slider(
                    min: 0.3,
                    max: 10,
                    value: b.q.clamp(0.3, 10.0),
                    onChanged: (v) =>
                        App.settings.setEq(s.withBand(index, b.copyWith(q: v))),
                  ),
                  const Text(
                    'On Android the system equalizer has fixed hardware bands, so '
                    'frequency and Q change the curve above but are only approximated in the sound.',
                    style: TextStyle(fontSize: 12, color: LColors.silverDim),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.s);
  final EqState s;
  static const _fMin = 20.0, _fMax = 20000.0, _range = 15.0;

  double _x(double f, Size sz) =>
      sz.width * (math.log(f / _fMin) / math.log(_fMax / _fMin));
  double _y(double db, Size sz) =>
      sz.height * (0.5 - db.clamp(-_range, _range) / (2 * _range));

  @override
  void paint(Canvas canvas, Size sz) {
    final grid = Paint()
      ..color = LColors.border
      ..strokeWidth = 1;
    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      canvas.drawLine(Offset(0, _y(db, sz)), Offset(sz.width, _y(db, sz)),
          db == 0 ? (Paint()..color = LColors.silverDim..strokeWidth = 1) : grid);
    }
    for (final f in [100.0, 1000.0, 10000.0]) {
      canvas.drawLine(Offset(_x(f, sz), 0), Offset(_x(f, sz), sz.height), grid);
    }
    final path = Path();
    const n = 160;
    for (var i = 0; i <= n; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / n);
      final db = s.enabled ? responseDb(s, f.toDouble()) : 0.0;
      final o = Offset(_x(f.toDouble(), sz), _y(db, sz));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = s.enabled ? LColors.electric : LColors.silverDim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (final b in s.bands) {
      canvas.drawCircle(Offset(_x(b.freq, sz), _y(b.gainDb, sz)), 3,
          Paint()..color = LColors.silver);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.s != s;
}
